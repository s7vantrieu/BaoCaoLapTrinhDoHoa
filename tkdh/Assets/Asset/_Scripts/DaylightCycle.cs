using UnityEngine;

public class DaylightCycle : MonoBehaviour
{
    [Header("Lighting Components")]
    public Light sunLight;
    
    [Header("Time Settings")]
    [Tooltip("Thời gian hiện tại trong ngày (0.0 đến 24.0)")]
    [Range(0f, 24f)]
    public float currentTimeOfDay = 10.96f; // Khởi tạo ở 10:58 AM
    
    [Tooltip("Tốc độ trôi của thời gian. 1 = thời gian thực. 60 = 1 giây ngoài đời bằng 1 phút trong game")]
    public float timeMultiplier = 60f; 

    [Header("Sun Angles")]
    public float sunTilt = 50f; // Độ nghiêng của trục mặt trời (để bóng đổ có độ chéo đẹp)

    void Update()
    {
        UpdateTime();
        UpdateSunRotation();
        UpdateSunIntensity();
    }

    void UpdateTime()
    {
        // Tăng thời gian theo frame
        currentTimeOfDay += (Time.deltaTime / 3600f) * timeMultiplier;

        // Reset về 0 khi qua ngày mới
        if (currentTimeOfDay >= 24f)
        {
            currentTimeOfDay = 0f;
        }
    }

    void UpdateSunRotation()
    {
        if (sunLight == null) return;

        // Bản đồ hóa 24 giờ thành 360 độ:
        // 0h: -90 độ (Dưới đất)
        // 6h sáng: 0 độ (Chân trời)
        // 12h trưa: 90 độ (Đỉnh đầu)
        // 18h tối: 180 độ (Chân trời lặn)
        float sunAngle = (currentTimeOfDay / 24f) * 360f - 90f;
        
        sunLight.transform.rotation = Quaternion.Euler(sunAngle, sunTilt, 0f);
    }

    void UpdateSunIntensity()
    {
        if (sunLight == null) return;

        // Bật tắt/giảm sáng bóng đổ khi đêm xuống
        if (currentTimeOfDay <= 5f || currentTimeOfDay >= 19f)
        {
            // Ban đêm
            sunLight.intensity = Mathf.MoveTowards(sunLight.intensity, 0.1f, Time.deltaTime);
        }
        else if (currentTimeOfDay > 5f && currentTimeOfDay < 7f)
        {
            // Bình minh: sáng dần
            sunLight.intensity = Mathf.MoveTowards(sunLight.intensity, 1f, Time.deltaTime * 0.5f);
        }
        else if (currentTimeOfDay > 17f && currentTimeOfDay < 19f)
        {
            // Hoàng hôn: tối dần
            sunLight.intensity = Mathf.MoveTowards(sunLight.intensity, 0.1f, Time.deltaTime * 0.5f);
        }
        else
        {
            // Ban ngày
            sunLight.intensity = 1f;
        }
    }
}