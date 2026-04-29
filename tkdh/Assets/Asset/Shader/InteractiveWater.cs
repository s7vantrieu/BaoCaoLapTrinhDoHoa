using UnityEngine;

public class InteractiveWater : MonoBehaviour
{
    public Camera cam;
    public Material waterMaterial; // Kéo Material của mặt nước vào đây
    public LayerMask waterLayer;   // Tạo một Layer "Water" gán cho mặt hồ, và set ở đây

    void Update()
    {
        if (Input.GetMouseButtonDown(0))
        {
            Ray ray = cam.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;

            // Bắn tia kiểm tra xem có trúng mặt nước không
            if (Physics.Raycast(ray, out hit, 100f, waterLayer))
            {
                // Gửi tọa độ trúng (Vector4) vào Shader
                waterMaterial.SetVector("_RipplePos", hit.point);
                
                // Gửi thời gian hiện tại (Time.time) vào Shader
                waterMaterial.SetFloat("_RippleTime", Time.time);
            }
        }
    }
}