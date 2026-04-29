# Báo Cáo: Shader HLSL và Công Nghệ Sinh Terrain Procedural

**Dự Án:** TKDH - Diorama Terrain System  
**Pipeline:** Universal Render Pipeline (URP)  
**Ngày:** Tháng 4, 2026  

---

## Mục Lục

1. [Tổng Quan Hệ Thống](#1-tổng-quan-hệ-thống)
2. [Công Nghệ Sinh Terrain (ProceduralTerrain.cs)](#2-công-nghệ-sinh-terrain)
3. [Shader Mountain – Terrain Chính](#3-shader-mountain--terrain-chính)
4. [Shader Grass – Cỏ Động Billboard](#4-shader-grass--cỏ-động-billboard)
5. [Shader Cloud – Mây Procedural](#5-shader-cloud--mây-procedural)
6. [Shader Water – Nước Động](#6-shader-water--nước-động)
7. [Các Thuật Toán Cốt Lõi](#7-các-thuật-toán-cốt-lõi)
8. [Tối Ưu Hiệu Suất](#8-tối-ưu-hiệu-suất)
9. [Kết Luận](#9-kết-luận)

---

## 1. Tổng Quan Hệ Thống

Dự án xây dựng một **Diorama Island** hoàn chỉnh bằng cách kết hợp:

- **Procedural Generation (C#):** Sinh heightmap, mesh terrain, lớp nước, và lớp cỏ hoàn toàn bằng code tại runtime.
- **Custom HLSL Shader (URP):** 4 shader viết tay trực tiếp bằng HLSL – không dùng ShaderGraph.

| Thành Phần | Script/Shader | Kỹ Thuật |
|---|---|---|
| Terrain | `ProceduralTerrain.cs` + `Mountain.shader` | Perlin Noise + Falloff + Vertex Displacement |
| Cỏ | `ProceduralTerrain.cs` + `Grass.shader` | Billboard X-Cross + **GPU Instancing** + Wind Animation |
| Mây | `Cloud.shader` | FBM Procedural Noise |
| Nước | `WaterTest.shader` | Dual Normal Map Scrolling + Specular |

---

## 2. Công Nghệ Sinh Terrain

**File:** `Assets/Asset/_Scripts/ProceduralTerrain.cs`

### 2.1 Quy Trình Khởi Tạo

```
Start()
  ├── GenerateIslandHeightMap()   [Perlin Noise × Falloff Mask → Texture2D 256×256]
  ├── GenerateTerrainMesh()       [HeightMap → Mesh (resolution+1)² đỉnh]
  ├── ApplyTerrainMaterial()      [Gán shader + truyền textures]
  ├── GenerateWaterLayer()        [Tạo mesh phẳng tại waterLevel]
  └── GenerateGrassInstanced()    [Matrix4x4[] + Graphics.DrawMeshInstanced()]
```

### 2.2 Sinh HeightMap – `GenerateIslandHeightMap()`

HeightMap 256×256 được sinh hoàn toàn bằng code, không cần file ảnh ngoài.

**Bước 1 – Perlin Noise:**
```csharp
float xCoord = (float)x / texRes * noiseScale + offsetX;
float yCoord = (float)y / texRes * noiseScale + offsetY;
float noiseVal = Mathf.PerlinNoise(xCoord, yCoord);
```
- `noiseScale` điều khiển tần số núi (nhỏ = nhiều đỉnh, lớn = núi thoải)
- `offsetX/Y` ngẫu nhiên từ `seed` → mỗi seed cho bản đồ khác nhau

**Bước 2 – Falloff Mask (tạo hình đảo tròn):**
```csharp
float nx = (float)x / texRes * 2f - 1f; // [-1, 1]
float ny = (float)y / texRes * 2f - 1f;
float distance = Mathf.Sqrt(nx * nx + ny * ny);
float falloff = Mathf.Clamp01(1f - Mathf.Pow(distance * islandSize, 3f));
```
- Công thức: `1 - (d × islandSize)³` → gradient từ 1 (tâm) về 0 (mép)
- `islandSize` (0.1–3.0) điều chỉnh bán kính đảo

**Bước 3 – Kết Hợp:**
```csharp
float finalHeight = noiseVal * falloff; // [0, 1]
pixels[y * texRes + x] = new Color(finalHeight, finalHeight, finalHeight);
```

### 2.3 Sinh Mesh Terrain – `GenerateTerrainMesh()`

```csharp
// (resolution+1)² đỉnh, mặc định resolution=100 → 10,201 đỉnh
for (int z = 0; z <= resolution; z++) {
    for (int x = 0; x <= resolution; x++) {
        float u = (float)x / resolution;
        float v = (float)z / resolution;
        float hValue = heightMap.GetPixelBilinear(u, v).r;
        
        vertices[i] = new Vector3(
            (u - 0.5f) * width,       // X: [-25, 25]
            hValue * mountainHeight,   // Y: Độ cao từ HeightMap
            (v - 0.5f) * depth        // Z: [-25, 25]
        );
    }
}
```

Sau đó dùng vòng lặp chia quad thành 2 tam giác (6 index mỗi ô lưới).

### 2.4 Sinh Cỏ – GPU Instancing

**Phương pháp mới:** Thay vì gộp tất cả ngọn cỏ vào 1 mesh khổng lồ (tốn RAM), hệ thống dùng **`Graphics.DrawMeshInstanced()`** để GPU tự nhân bản 1 mesh ngọn cỏ duy nhất ra hàng nghìn vị trí.

#### Bước 1 – Tạo Mesh 1 Ngọn Cỏ (`CreateSingleGrassMesh`)

Mesh hình chữ X gồm 2 quad vuông góc → 8 đỉnh, 16 tam giác:

```csharp
float hw = 0.5f, h = 1f;
// Quad 1 (song song trục Z) + Quad 2 (song song trục X)
var verts = new Vector3[] {
    new Vector3(-hw, 0f, 0f), new Vector3(hw, 0f, 0f),
    new Vector3(-hw, h*2f, 0f), new Vector3(hw, h*2f, 0f),
    new Vector3(0f, 0f, -hw), new Vector3(0f, 0f, hw),
    new Vector3(0f, h*2f, -hw), new Vector3(0f, h*2f, hw),
};
// Mỗi quad: 2 mặt (front + back) → Cull Off trong shader
var tris = new int[] {
    0,2,1, 1,2,3,  1,2,0, 3,2,1,  // Quad 1
    4,6,5, 5,6,7,  5,6,4, 7,6,5,  // Quad 2
};
```

#### Bước 2 – Thu Thập Ma Trận (`GenerateGrassInstanced`)

Thay vì lưu vị trí trong vertex buffer, mỗi ngọn cỏ được đại diện bằng 1 `Matrix4x4` (vị trí + góc xoay Y ngẫu nhiên + scale):

```csharp
grassMaterial.enableInstancing = true; // Bật GPU Instancing trên material

for (int i = 0; i < grassCount; i++) {
    float hValue = GetHeightMapValue(randX, randZ);
    float yPos   = hValue * mountainHeight + grassYOffset;
    if (yPos < waterLevel + 0.5f || hValue > 0.5f) continue; // Lọc vùng không hợp lệ

    matrices.Add(Matrix4x4.TRS(
        new Vector3(randX, yPos, randZ), // Vị trí theo HeightMap
        Quaternion.Euler(0f, rotY, 0f),  // Xoay Y ngẫu nhiên → cỏ không đồng đều
        Vector3.one * size               // Scale ngẫu nhiên ±30%
    ));
}
```

#### Bước 3 – Pre-slice Thành Batch (`Start`)

Unity giới hạn **1023 instance/lần gọi** `DrawMeshInstanced`. Để tránh tạo mảng tạm mỗi frame (GC pressure), ta chia sẵn trong `Start()`:

```csharp
const int INSTANCED_BATCH_SIZE = 1023;
grassBatches = new List<Matrix4x4[]>();
for (int i = 0; i < matrices.Count; i += INSTANCED_BATCH_SIZE) {
    int count = Mathf.Min(INSTANCED_BATCH_SIZE, matrices.Count - i);
    var batch = new Matrix4x4[count];
    matrices.CopyTo(i, batch, 0, count);
    grassBatches.Add(batch); // Lưu batch cố định → dùng lại mỗi frame
}
```

#### Bước 4 – Vẽ Mỗi Frame (`Update`)

```csharp
void Update() {
    foreach (var batch in grassBatches)
        Graphics.DrawMeshInstanced(
            singleGrassMesh, 0,       // Mesh + submesh index
            grassMaterial,             // Material có enableInstancing = true
            batch, batch.Length,       // Mảng Matrix4x4 pre-sliced
            grassPropertyBlock         // Per-instance properties (nếu cần)
        );
}
```

> **Lợi ích so với CombinedMesh:**
> - GPU chỉ upload 1 mesh duy nhất (8 đỉnh) thay vì mesh khổng lồ 80,000+ đỉnh
> - Không cần `IndexFormat.UInt32` (giảm memory)
> - GPU tự nhân bản qua hardware instancing → không tốn CPU bandwidth

---

## 3. Shader Mountain – Terrain Chính

**File:** `Assets/Asset/Mountain/Mountain.shader`  
**Tên Shader:** `Diorama/URP_TerrainEcosystem`

### 3.1 Cấu Trúc Shader

Shader có **2 Pass:**
- `ForwardLit` – Render màu terrain với ánh sáng Lambert
- `ShadowCaster` – Đổ bóng đúng hình núi lồi lõm

### 3.2 Vertex Shader – Đẩy Núi Lên

```hlsl
Varyings vert(Attributes input) {
    // Đọc HeightMap tại vị trí UV (dùng tex2Dlod trong vertex stage)
    float4 heightData = tex2Dlod(_HeightMap, float4(input.uv, 0, 0));
    float h = heightData.r;
    
    // Đẩy Y lên theo độ cao
    input.positionOS.y += h * _Height;
    
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS   = TransformObjectToWorldNormal(input.normalOS);
    output.hValue     = h; // Truyền xuống Fragment để phân tầng màu
}
```

> **Lưu ý:** Trong Vertex Shader phải dùng `tex2Dlod` (LOD=0) thay vì `tex2D` vì GPU không thể tự tính mipmap ở giai đoạn vertex.

### 3.3 Fragment Shader – Phân Tầng Màu Theo Độ Cao

```hlsl
half4 frag(Varyings input) : SV_Target {
    half4 colGrass = tex2D(_GrassTex, input.uv);
    half4 colRock  = tex2D(_RockTex,  input.uv);
    half4 colSnow  = tex2D(_SnowTex,  input.uv);

    float h = input.hValue;
    half4 baseColor;

    if      (h < 0.3) baseColor = colGrass;
    else if (h < 0.5) baseColor = lerp(colGrass, colRock, (h - 0.3) * 5.0);
    else if (h < 0.7) baseColor = colRock;
    else if (h < 0.9) baseColor = lerp(colRock, colSnow, (h - 0.7) * 5.0);
    else              baseColor = colSnow;
    
    // Lambert Lighting
    Light mainLight = GetMainLight();
    float NdotL = saturate(dot(input.normalWS, mainLight.direction));
    half3 finalRGB = baseColor.rgb * mainLight.color * NdotL
                   + baseColor.rgb * 0.2; // Ambient để mặt tối không đen kịt
    return half4(finalRGB, 1.0);
}
```

**Bảng Phân Tầng Sinh Thái:**

| Độ cao (h) | Vật liệu | Ghi chú |
|---|---|---|
| < 0.3 | Cỏ | Vùng thấp ven biển |
| 0.3 – 0.5 | Cỏ → Đá | Lerp chuyển mượt |
| 0.5 – 0.7 | Đá | Sườn núi |
| 0.7 – 0.9 | Đá → Tuyết | Lerp chuyển mượt |
| > 0.9 | Tuyết | Đỉnh núi |

### 3.4 Shadow Caster Pass

```hlsl
Varyings vertShadow(Attributes input) {
    // Phải đẩy đỉnh lên đúng như ForwardLit
    // để bóng in ra đúng hình núi lồi lõm
    float4 heightData = tex2Dlod(_HeightMap, float4(input.uv, 0, 0));
    input.positionOS.y += heightData.r * _Height;
    
    float3 positionWS  = TransformObjectToWorld(input.positionOS.xyz);
    output.positionCS  = TransformWorldToHClip(positionWS);
}

half4 fragShadow(Varyings input) : SV_Target {
    return 0; // Chỉ ghi depth buffer, không trả màu
}
```

---

## 4. Shader Grass – Cỏ Động Billboard

**File:** `Assets/Asset/Shader/Grass.shader`  
**Tên Shader:** `Diorama/URP_Grass_3DVolume`

### 4.1 Thiết Lập Render State

```hlsl
Tags { "RenderType"="TransparentCutout" "Queue"="AlphaTest" }
Cull Off  // Thấy cả 2 mặt của chữ X
```

### 4.2 Vertex Shader – Hiệu Ứng Gió

```hlsl
Varyings vert(Attributes IN) {
    float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
    
    // Gió sin/cos theo thời gian, chỉ ảnh hưởng phần ngọn (IN.uv.y)
    float windX = sin(_Time.y * _WindSpeed + worldPos.x) * _WindStrength * IN.uv.y;
    float windZ = cos(_Time.y * _WindSpeed * 0.8 + worldPos.z) * _WindStrength * IN.uv.y;
    
    worldPos.x += windX;
    worldPos.z += windZ;
    
    OUT.positionCS = TransformWorldToHClip(worldPos);
    // Fix normal luôn hướng lên để đón ánh sáng mặt trời
    OUT.normalWS = float3(0, 1, 0);
}
```

- `IN.uv.y` = 0 ở gốc cỏ → gốc bất động; = 1 ở ngọn → ngọn dao động mạnh nhất
- Dùng `sin` cho X và `cos * 0.8` cho Z → gió không đều, tự nhiên hơn

### 4.3 Fragment Shader – Alpha Cutout + Lighting

```hlsl
half4 frag(Varyings IN) : SV_Target {
    half4 texColor = tex2D(_BaseMap, IN.uv);
    clip(texColor.a - _Cutoff); // Cắt pixel trong suốt
    
    Light mainLight = GetMainLight();
    float NdotL = saturate(dot(IN.normalWS, mainLight.direction));
    float3 diffuse = mainLight.color * (NdotL + 0.3); // +0.3 ambient
    
    float3 finalColor = (texColor.rgb * _BaseColor.rgb) * diffuse;
    return half4(finalColor, 1.0);
}
```

---

## 5. Shader Cloud – Mây Procedural

**File:** `Assets/Asset/Shader/Cloud.shader`  
**Tên Shader:** `Diorama/URP_ProceduralClouds`

Mây được sinh **hoàn toàn bằng toán học**, không cần texture.

### 5.1 Hàm Noise Nền Tảng

**Hash Function (giả ngẫu nhiên):**
```hlsl
float hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return frac(sin(h) * 43758.5453123);
}
```

**Value Noise (nội suy mượt):**
```hlsl
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f); // Smoothstep nội suy

    return lerp(
        lerp(hash(i + float2(0,0)), hash(i + float2(1,0)), f.x),
        lerp(hash(i + float2(0,1)), hash(i + float2(1,1)), f.x),
        f.y
    );
}
```

**Fractal Brownian Motion (4 octave):**
```hlsl
float fbm(float2 p) {
    float f = 0.0, amp = 0.5;
    for(int i = 0; i < 4; i++) {
        f   += amp * noise(p);
        p   *= 2.0;   // Zoom in gấp đôi
        amp *= 0.5;   // Giảm biên độ
    }
    return f;
}
```

Tổng hợp: `f = 0.5·noise(p) + 0.25·noise(2p) + 0.125·noise(4p) + 0.0625·noise(8p)`

### 5.2 Fragment Shader – Tạo Hình Mây

```hlsl
half4 frag(Varyings IN) : SV_Target {
    // UV trôi theo thời gian
    float2 scrolledUV = IN.uv * _Scale + float2(_Time.y * _Speed, _Time.y * _Speed * 0.7);
    
    float cloudNoise = fbm(scrolledUV);
    
    // Smoothstep tạo viền mềm cho từng cụm mây
    float alpha = smoothstep(_Density - _Softness, _Density + _Softness, cloudNoise);
    
    // Làm mờ mép lưới để không lộ hình vuông
    float distFromCenter = distance(IN.uv, float2(0.5, 0.5));
    float radialFade = 1.0 - smoothstep(0.2, 0.5, distFromCenter);
    
    float finalAlpha = alpha * _CloudColor.a * radialFade;
    return half4(_CloudColor.rgb, finalAlpha);
}
```

**Tham số điều chỉnh:**

| Property | Tác Dụng |
|---|---|
| `_Density` | Ngưỡng cắt noise → mây dày/thưa |
| `_Softness` | Bán kính smoothstep → viền cứng/mềm |
| `_Speed` | Tốc độ trôi theo UV |
| `_Scale` | Kích thước cụm mây |

---

## 6. Shader Water – Nước Động

**File:** `Assets/Asset/Shader/WaterTest.shader`  
**Tên Shader:** `Diorama/URP_Water_Optimized`

### 6.1 Thiết Lập Render State

```hlsl
Tags { "RenderType"="Transparent" "Queue"="Transparent" }
Blend SrcAlpha OneMinusSrcAlpha
ZWrite Off  // Không ghi depth để không che cắt terrain bên dưới
```

Vertex shader **không có vertex displacement** – mặt nước phẳng tĩnh, sóng được mô phỏng hoàn toàn bằng Normal Map.

### 6.2 Fragment Shader – Dual Normal Map Blending

```hlsl
// Hai lớp UV cuộn với hướng và tốc độ khác nhau
float2 uv1 = IN.uv + _Scroll1 * _Time.y;
float2 uv2 = IN.uv * 1.5 + _Scroll2 * _Time.y; // Scale 1.5x → sóng to nhỏ lồng nhau

float3 normal1 = UnpackNormalScale(tex2D(_NormalMap, uv1), _BumpScale);
float3 normal2 = UnpackNormalScale(tex2D(_NormalMap, uv2), _BumpScale);

// Blend: cộng xy (hướng lệch), nhân z (cường độ)
float3 blendedNormalTS = normalize(float3(normal1.xy + normal2.xy, normal1.z * normal2.z));

// Chuyển từ Tangent Space sang World Space qua ma trận TBN
float3x3 TBN = float3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS);
float3 finalNormalWS = normalize(mul(blendedNormalTS, TBN));
```

### 6.3 Tính Ánh Sáng Nước

```hlsl
// Diffuse (Lambert)
float NdotL = saturate(dot(finalNormalWS, lightDir));
float3 diffuse = mainLight.color * NdotL;

// Specular (Blinn-Phong)
float3 halfVector = normalize(lightDir + viewDir);
float NdotH = saturate(dot(finalNormalWS, halfVector));
float specularPower = exp2(10.0 * _Smoothness + 1.0);
float specular = pow(NdotH, specularPower) * _Smoothness;

// Ambient (giữ màu nước trong bóng tối)
float3 ambient = float3(0.1, 0.15, 0.25);

float3 finalRGB = _WaterColor.rgb * (diffuse + ambient) + (mainLight.color * specular);
return half4(finalRGB, _WaterColor.a);
```

---

## 7. Các Thuật Toán Cốt Lõi

### 7.1 Perlin Noise

Hàm nhiễu liên tục trả về giá trị [0,1] từ tọa độ 2D. Được dùng ở:
- **C# (`Mathf.PerlinNoise`):** Sinh heightmap terrain
- **HLSL (Cloud.shader):** Tạo hình dạng mây theo từng pixel

Tính chất: cùng đầu vào → cùng đầu ra (deterministic), nhưng trông như ngẫu nhiên.

### 7.2 Falloff Mask

```
falloff = clamp(1 - (distance × intensity)^power, 0, 1)
```

Áp dụng ở 2 nơi:
- **HeightMap:** Ép địa hình thành hình đảo tròn
- **Cloud radialFade:** Làm mờ viền mesh để mây trông vô hạn

### 7.3 Fractal Brownian Motion (FBM)

Cộng nhiều lớp noise ở tần số tăng dần, biên độ giảm dần:

```
FBM(p) = Σ (0.5^i × noise(2^i × p))   với i = 0..3
```

Kết quả: chi tiết tự nhiên từ quy mô lớn (hình dáng cụm mây) đến nhỏ (texture bề mặt).

### 7.4 Height-based Material Blending

Chọn texture dựa vào giá trị `hValue` truyền từ Vertex → Fragment, dùng `lerp` tại ngưỡng chuyển tiếp tạo gradient mượt. Không cần UV channel phụ hay vertex paint.

### 7.5 Tangent Space Normal Mapping

Ma trận TBN (Tangent-Bitangent-Normal) chuyển normal từ Tangent Space → World Space, cho phép ánh sáng tính đúng trên bề mặt cong.

---

## 8. Tối Ưu Hiệu Suất

### 8.1 GPU Instancing – Hệ Thống Cỏ

**Nguyên lý:** GPU nhân bản 1 mesh ngọn cỏ (8 đỉnh) ra N vị trí khác nhau thông qua bảng `Matrix4x4[]`, thay vì upload toàn bộ geometry lên VRAM.

```
CPU                          GPU
─────────────────────────────────────────────────────
Matrix4x4[1023]  ──────►  Instance 0:  Transform_0 × GrassBlade
                           Instance 1:  Transform_1 × GrassBlade
                           ...          ...
                           Instance N:  Transform_N × GrassBlade
─────────────────────────────────────────────────────
Chỉ 1 Mesh upload, N lần render với transform khác nhau
```

**So Sánh Hai Phương Pháp:**

| Tiêu Chí | CombinedMesh (cũ) | GPU Instancing (mới) |
|---|---|---|
| VRAM (10k cỏ) | ~3.2 MB vertex buffer | ~384 B (8 đỉnh × 48B) |
| CPU/frame | 0 (mesh tĩnh) | Duyệt `grassBatches` list |
| Draw call | 1 | ⌈N/1023⌉ (~10 batch) |
| Thêm cỏ sau | Phải rebuild mesh | Thêm `Matrix4x4` vào list |
| IndexFormat | UInt32 (bắt buộc) | UInt16 (đủ dùng) |

### 8.2 Giảm Draw Call Tổng Thể

| Thành Phần | Chiến Lược | Draw Call |
|---|---|---|
| Terrain | 1 mesh duy nhất | 1 |
| Nước | 1 mesh duy nhất | 1 |
| Cỏ 10,000 ngọn | `DrawMeshInstanced` batch 1023 | ~10 batch |

### 8.2 Mesh Geometry

| Tham Số | Giá Trị | Lý Do |
|---|---|---|
| `resolution` | 100 | 10,201 đỉnh – đủ mịn, không quá nặng |
| `texRes` (HeightMap) | 256×256 | Đủ cho terrain 50×50 unit |
| `grassCount` | 10,000 | Cân bằng chi tiết và FPS |

### 8.3 Tối Ưu Shader

| Shader | Kỹ Thuật Tiết Kiệm |
|---|---|
| Mountain | Vertex Y-offset (thay vì geometry shader phức tạp) |
| Grass | Billboard 2D, `Cull Off` (thay vì 3D model) |
| Cloud | Procedural noise (không cần texture bandwidth) |
| Water | Flat mesh + normal map (không cần vertex displacement) |

### 8.4 Sinh Tại Start(), Render Qua Update()

- **Terrain, Nước:** Mesh tạo 1 lần trong `Start()`, giao Unity quản lý qua `MeshRenderer` – zero overhead.
- **Cỏ (GPU Instancing):** `Matrix4x4[]` tính 1 lần trong `Start()`, sau đó `Update()` chỉ gọi `DrawMeshInstanced` với batch pre-sliced sẵn → **không có GC allocation mỗi frame**.

---

## 9. Kết Luận

### Điểm Mạnh

| | Nội dung |
|---|---|
| ✅ | **Pure HLSL:** Toàn bộ 4 shader viết tay, không ShaderGraph → hiểu sâu pipeline |
| ✅ | **Procedural hoàn toàn:** Terrain, cỏ, mây sinh từ code – không cần asset ngoài |
| ✅ | **GPU Instancing:** Cỏ 10k ngọn render qua `DrawMeshInstanced` – tiết kiệm VRAM |
| ✅ | **Zero GC/frame:** Batch matrix pre-sliced sẵn, không allocation trong Update() |
| ✅ | **Seed-based:** Có thể sinh bản đồ mới chỉ bằng thay số `seed` |
| ✅ | **Shadow Caster đúng:** Pass riêng đảm bảo bóng in chính xác theo địa hình |

### Hạn Chế & Đề Xuất Nâng Cấp

| Hạn Chế | Đề Xuất |
|---|---|
| HeightMap chỉ sinh 1 lần | Compute Shader sinh HeightMap trên GPU |
| Không có LOD | Thêm `LODGroup` hoặc `DrawMeshInstancedIndirect` |
| Cloud là mesh phẳng hữu hạn | Dùng Ray-marching volumetric cloud |
| Không Multi-octave HeightMap | Dùng Octave Perlin Noise (FBM trên CPU) |

---

## Tham Chiếu File

**C# Scripts:**
- `Assets/Asset/_Scripts/ProceduralTerrain.cs` – Toàn bộ logic sinh terrain, nước, cỏ

**HLSL Shaders:**
- `Assets/Asset/Mountain/Mountain.shader` – `Diorama/URP_TerrainEcosystem`
- `Assets/Asset/Shader/Grass.shader` – `Diorama/URP_Grass_3DVolume`
- `Assets/Asset/Shader/Cloud.shader` – `Diorama/URP_ProceduralClouds`
- `Assets/Asset/Shader/WaterTest.shader` – `Diorama/URP_Water_Optimized`

**Textures:**
- `Assets/Asset/Mountain/grass.bmp`, `rock.bmp`, `snowrocks.bmp`
- `Assets/Asset/Shader/4141-normal.jpg` (Normal map cho nước)

**Tài Liệu Tham Khảo:**
- Unity URP ShaderLibrary: `Core.hlsl`, `Lighting.hlsl`, `Shadows.hlsl`
- Perlin Noise: https://en.wikipedia.org/wiki/Perlin_noise
- Fractal Brownian Motion: https://iquilezles.org/articles/fbm/

---

*End of Report*
