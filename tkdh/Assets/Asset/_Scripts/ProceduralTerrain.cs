using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class ProceduralTerrain : MonoBehaviour
{
    [Header("Cấu hình Lưới (Mesh)")]
    public float width = 50f;
    public float depth = 50f;
    [Range(10, 250)] public int resolution = 100; 

    [Header("Hệ Thống Sinh Dữ Liệu (Procedural Generation)")]
    public bool useSeed = true;
    public int seed = 12345;
    [Tooltip("Độ thu phóng của đồi núi. Càng nhỏ núi càng chi chít, càng to núi càng thoai thoải.")]
    public float noiseScale = 3f;
    [Tooltip("Kích thước của hòn đảo (ép các mép chìm xuống nước)")]
    [Range(0.1f, 3f)] public float islandSize = 1.5f;

    [Header("Cấu hình Đất/Núi")]
    public Shader terrainShader;
    [Tooltip("Nếu Use Seed = true, ảnh này sẽ tự động được máy tính vẽ đè lên.")]
    public Texture2D heightMap; 
    public Texture2D grassTex;
    public Texture2D rockTex;
    public Texture2D snowTex;
    [Range(1f, 20f)] public float mountainHeight = 10f;

    [Header("Cấu hình Nước (Water Layer)")]
    public bool generateWater = true;
    public Material waterMaterial; 
    [Range(0f, 15f)] public float waterLevel = 3f;

    [Header("Cấu hình Cỏ Động (Wind Grass)")]
    public bool generateGrass = true;
    public Material grassMaterial; 
    [Range(1000, 20000)] public int grassCount = 10000;
    public float grassSize = 1.0f;
    [Range(-5f, 5f)] public float grassYOffset = 0f; 

    private Mesh terrainMesh;

    // --- GPU Instancing (Grass) ---
    private List<Matrix4x4[]> grassBatches;
    private Mesh singleGrassMesh;
    private MaterialPropertyBlock grassPropertyBlock;
    private const int INSTANCED_BATCH_SIZE = 1023; // Unity giới hạn tối đa 1023 instance/lần gọi

    void Start()
    {
        // 1. TỰ ĐỘNG VẼ ẢNH HEIGHTMAP NẾU BẬT USE SEED
        if (useSeed)
        {
            heightMap = GenerateIslandHeightMap();
        }

        // 2. Tạo Đất
        GenerateTerrainMesh();
        ApplyTerrainMaterial();

        // 3. Tạo Nước
        if (generateWater) GenerateWaterLayer();

        // 4. Trồng Cỏ
        if (generateGrass) GenerateGrassInstanced();
    }

    // --- THUẬT TOÁN SINH ĐẢO THEO SEED ---
    Texture2D GenerateIslandHeightMap()
    {
        int texRes = 256; // Độ phân giải ảnh map
        Texture2D tex = new Texture2D(texRes, texRes);
        Color[] pixels = new Color[texRes * texRes];

        // Khởi tạo bộ sinh số ngẫu nhiên theo Seed
        System.Random prng = new System.Random(seed);
        float offsetX = prng.Next(-100000, 100000);
        float offsetY = prng.Next(-100000, 100000);

        for (int y = 0; y < texRes; y++)
        {
            for (int x = 0; x < texRes; x++)
            {
                // 1. Lấy nhiễu Perlin (Tạo đồi núi nhấp nhô)
                float xCoord = (float)x / texRes * noiseScale + offsetX;
                float yCoord = (float)y / texRes * noiseScale + offsetY;
                float noiseVal = Mathf.PerlinNoise(xCoord, yCoord);

                // 2. Tính toán mặt nạ Falloff (Ép thành hình đảo tròn)
                float nx = (float)x / texRes * 2f - 1f; // Chuyển dải 0..1 thành -1..1
                float ny = (float)y / texRes * 2f - 1f;
                // Tính khoảng cách từ tâm ra mép
                float distance = Mathf.Sqrt(nx * nx + ny * ny); 
                // Càng ra xa tâm càng tiến về 0
                float falloff = Mathf.Clamp01(1f - Mathf.Pow(distance * islandSize, 3f)); 

                // 3. Áp dụng mặt nạ vào đồi núi
                float finalHeight = noiseVal * falloff;
                
                pixels[y * texRes + x] = new Color(finalHeight, finalHeight, finalHeight);
            }
        }
        
        tex.SetPixels(pixels);
        tex.Apply();
        return tex;
    }

    // ... CÁC HÀM GenerateTerrainMesh(), ApplyTerrainMaterial(), GenerateWaterLayer() GIỮ NGUYÊN ...
    
    void GenerateTerrainMesh()
    {
        terrainMesh = new Mesh();
        terrainMesh.name = "Procedural Terrain";
        GetComponent<MeshFilter>().mesh = terrainMesh;

        Vector3[] vertices = new Vector3[(resolution + 1) * (resolution + 1)];
        Vector2[] uvs = new Vector2[vertices.Length];

        for (int i = 0, z = 0; z <= resolution; z++)
        {
            for (int x = 0; x <= resolution; x++)
            {
                float xPos = ((float)x / resolution - 0.5f) * width;
                float zPos = ((float)z / resolution - 0.5f) * depth;
                float yPos = 0f;

                uvs[i] = new Vector2((float)x / resolution, (float)z / resolution);
                if (heightMap != null)
                {
                    float hValue = heightMap.GetPixelBilinear(uvs[i].x, uvs[i].y).r;
                    yPos = hValue * mountainHeight;
                }

                vertices[i] = new Vector3(xPos, yPos, zPos);
                i++;
            }
        }

        int[] triangles = new int[resolution * resolution * 6];
        int vert = 0, tris = 0;

        for (int z = 0; z < resolution; z++)
        {
            for (int x = 0; x < resolution; x++)
            {
                triangles[tris + 0] = vert + 0;
                triangles[tris + 1] = vert + resolution + 1;
                triangles[tris + 2] = vert + 1;
                triangles[tris + 3] = vert + 1;
                triangles[tris + 4] = vert + resolution + 1;
                triangles[tris + 5] = vert + resolution + 2;
                vert++; tris += 6;
            }
            vert++;
        }

        terrainMesh.vertices = vertices;
        terrainMesh.uv = uvs;
        terrainMesh.triangles = triangles;
        terrainMesh.RecalculateNormals(); 
    }

    void ApplyTerrainMaterial()
    {
        if (terrainShader == null) terrainShader = Shader.Find("Diorama/URP_TerrainEcosystem");
        Material mat = new Material(terrainShader);

        if (heightMap) mat.SetTexture("_HeightMap", heightMap);
        if (grassTex) mat.SetTexture("_GrassTex", grassTex);
        if (rockTex) mat.SetTexture("_RockTex", rockTex);
        if (snowTex) mat.SetTexture("_SnowTex", snowTex);
        
        mat.SetFloat("_Height", mountainHeight);
        GetComponent<MeshRenderer>().material = mat;
    }

    void GenerateWaterLayer()
    {
        GameObject waterObj = new GameObject("Procedural Water Layer");
        waterObj.transform.SetParent(this.transform);
        waterObj.transform.localPosition = new Vector3(0, waterLevel, 0); 

        MeshFilter waterFilter = waterObj.AddComponent<MeshFilter>();
        MeshRenderer waterRenderer = waterObj.AddComponent<MeshRenderer>();

        Mesh waterMesh = new Mesh();
        waterMesh.name = "Procedural Water";
        
        Vector3[] vertices = new Vector3[(resolution + 1) * (resolution + 1)];
        Vector2[] uvs = new Vector2[vertices.Length];

        for (int i = 0, z = 0; z <= resolution; z++)
        {
            for (int x = 0; x <= resolution; x++)
            {
                float xPos = ((float)x / resolution - 0.5f) * width;
                float zPos = ((float)z / resolution - 0.5f) * depth;
                vertices[i] = new Vector3(xPos, 0, zPos); 
                uvs[i] = new Vector2((float)x / resolution, (float)z / resolution);
                i++;
            }
        }

        int[] triangles = new int[resolution * resolution * 6];
        int vert = 0, tris = 0;

        for (int z = 0; z < resolution; z++)
        {
            for (int x = 0; x < resolution; x++)
            {
                triangles[tris + 0] = vert + 0;
                triangles[tris + 1] = vert + resolution + 1;
                triangles[tris + 2] = vert + 1;
                triangles[tris + 3] = vert + 1;
                triangles[tris + 4] = vert + resolution + 1;
                triangles[tris + 5] = vert + resolution + 2;
                vert++; tris += 6;
            }
            vert++;
        }

        waterMesh.vertices = vertices;
        waterMesh.uv = uvs;
        waterMesh.triangles = triangles;
        waterMesh.RecalculateNormals();
        waterFilter.mesh = waterMesh;

        if (waterMaterial != null) waterRenderer.material = waterMaterial;
    }

    // --- GPU INSTANCING: Thay thế GenerateGrassLayer() ---
    void GenerateGrassInstanced()
    {
        if (grassMaterial == null || heightMap == null) return;

        // Bật GPU Instancing trên material
        grassMaterial.enableInstancing = true;

        // Tạo mesh 1 ngọn cỏ (X-cross) dùng chung cho mọi instance
        singleGrassMesh = CreateSingleGrassMesh();
        grassPropertyBlock = new MaterialPropertyBlock();

        var matrices = new List<Matrix4x4>();
        Random.InitState(seed);

        for (int i = 0; i < grassCount; i++)
        {
            float randX = Random.Range(-width / 2f, width / 2f);
            float randZ = Random.Range(-depth / 2f, depth / 2f);

            float hValue = GetHeightMapValue(randX, randZ);
            float yPos   = hValue * mountainHeight + grassYOffset;

            if (yPos < waterLevel + 0.5f || hValue > 0.5f) continue;

            float size = Random.Range(grassSize * 0.7f, grassSize * 1.3f);
            float rotY  = Random.Range(0f, 360f);

            // Mỗi ngọn cỏ là 1 Matrix4x4 (vị trí + xoay Y ngẫu nhiên + scale)
            matrices.Add(Matrix4x4.TRS(
                new Vector3(randX, yPos, randZ),
                Quaternion.Euler(0f, rotY, 0f),
                Vector3.one * size
            ));
        }

        // Pre-slice thành các mảng ≤ 1023 để tránh GC allocation mỗi frame
        grassBatches = new List<Matrix4x4[]>();
        for (int i = 0; i < matrices.Count; i += INSTANCED_BATCH_SIZE)
        {
            int count = Mathf.Min(INSTANCED_BATCH_SIZE, matrices.Count - i);
            var batch = new Matrix4x4[count];
            matrices.CopyTo(i, batch, 0, count);
            grassBatches.Add(batch);
        }
    }

    // Mesh 1 ngọn cỏ hình chữ X (8 đỉnh, 12 tam giác, render 2 mặt)
    Mesh CreateSingleGrassMesh()
    {
        float hw = 0.5f, h = 1f;
        var verts = new Vector3[]
        {
            // Quad 1 (song song trục Z)
            new Vector3(-hw, 0f,    0f), new Vector3(hw, 0f,    0f),
            new Vector3(-hw, h*2f, 0f), new Vector3(hw, h*2f, 0f),
            // Quad 2 (song song trục X)
            new Vector3(0f, 0f,    -hw), new Vector3(0f, 0f,    hw),
            new Vector3(0f, h*2f, -hw), new Vector3(0f, h*2f, hw),
        };
        var uvs = new Vector2[]
        {
            new Vector2(0,0), new Vector2(1,0), new Vector2(0,1), new Vector2(1,1),
            new Vector2(0,0), new Vector2(1,0), new Vector2(0,1), new Vector2(1,1),
        };
        // Mỗi quad có 2 mặt (front + back) → Cull Off trong shader
        var tris = new int[]
        {
            0,2,1, 1,2,3,  // Quad 1 front
            1,2,0, 3,2,1,  // Quad 1 back
            4,6,5, 5,6,7,  // Quad 2 front
            5,6,4, 7,6,5,  // Quad 2 back
        };
        var m = new Mesh { name = "GrassBlade_Instanced" };
        m.vertices  = verts;
        m.uv        = uvs;
        m.triangles = tris;
        m.RecalculateNormals();
        return m;
    }

    // Gọi mỗi frame: GPU vẽ tất cả instance không cần GameObject
    void Update()
    {
        if (grassBatches == null || singleGrassMesh == null || grassMaterial == null) return;
        foreach (var batch in grassBatches)
            Graphics.DrawMeshInstanced(singleGrassMesh, 0, grassMaterial, batch, batch.Length, grassPropertyBlock);
    }

    float GetHeightMapValue(float worldX, float worldZ)
    {
        if (heightMap == null) return 0f;

        float u = Mathf.Clamp01((worldX + width * 0.5f) / width);
        float v = Mathf.Clamp01((worldZ + depth * 0.5f) / depth);
        return heightMap.GetPixelBilinear(u, v).r;
    }
}