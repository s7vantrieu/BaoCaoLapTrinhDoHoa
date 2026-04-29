using UnityEngine;

public class DaylightCycle : MonoBehaviour
{
    [Header("Lighting Components")]
    public Light sunLight;
    
    [Header("Time Settings")]
    [Tooltip("Thời gian hiện tại trong ngày (0.0 đến 24.0)")]
    [Range(0f, 24f)]
    public float currentTimeOfDay = 12.96f; // Gần 1h chiều 
    
    public float timeMultiplier = 60f; 
    public float sunTilt = 50f; 

    [Header("Cloud & Environment")]
    public Material cloudMaterial; // Kéo CloudMat vào đây
    [Tooltip("Dải màu của mây theo thời gian (Từ 0h đến 24h)")]
    public Gradient cloudColorGradient; 

    void Update()
    {
        UpdateTime();
        UpdateSunRotation();
        UpdateSunIntensity();
        UpdateCloudColor(); // Gọi hàm cập nhật màu mây
    }

    void UpdateTime()
    {
        currentTimeOfDay += (Time.deltaTime / 3600f) * timeMultiplier;
        if (currentTimeOfDay >= 24f) currentTimeOfDay = 0f;
    }

    void UpdateSunRotation()
    {
        if (sunLight == null) return;
        float sunAngle = (currentTimeOfDay / 24f) * 360f - 90f;
        sunLight.transform.rotation = Quaternion.Euler(sunAngle, sunTilt, 0f);
    }

    void UpdateSunIntensity()
    {
        if (sunLight == null) return;

        if (currentTimeOfDay <= 5f || currentTimeOfDay >= 19f) {
            sunLight.intensity = Mathf.MoveTowards(sunLight.intensity, 0.1f, Time.deltaTime);
        }
        else if (currentTimeOfDay > 5f && currentTimeOfDay < 7f) {
            sunLight.intensity = Mathf.MoveTowards(sunLight.intensity, 1f, Time.deltaTime * 0.5f);
        }
        else if (currentTimeOfDay > 17f && currentTimeOfDay < 19f) {
            sunLight.intensity = Mathf.MoveTowards(sunLight.intensity, 0.1f, Time.deltaTime * 0.5f);
        }
        else {
            sunLight.intensity = 1f;
        }
    }

    // --- HÀM MỚI: ĐỔI MÀU MÂY THEO THỜI GIAN ---
    void UpdateCloudColor()
    {
        if (cloudMaterial != null)
        {
            // Chuyển thời gian (0-24) thành dải phần trăm (0.0 - 1.0) để lấy màu trong Gradient
            float timePercent = currentTimeOfDay / 24f;
            
            // Lấy màu tương ứng trên thanh Gradient
            Color currentColor = cloudColorGradient.Evaluate(timePercent);
            
            // Đẩy màu vào Shader Mây
            cloudMaterial.SetColor("_CloudColor", currentColor);
        }
    }
}