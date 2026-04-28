using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace tkdh
{
    public class MyCamera : MonoBehaviour
    {
        [Header("Camera Settings")]
        [Range(0, 120f)]
        public float fieldOfView = 30f;
        [Range(1, 1.5f)]
        public float aspectRatio = 1;
        public float near = 0;
        public float far = 0;

        [Header("View Screen Settings")]
        [Range(1, 150)]
        public int resolution = 0;
        public bool isDrawPixel = false;
        public bool isShowRay = false;

        [Header("Mirror Settings")]
        public bool isMirror = false; // Bật/tắt chế độ gương
        public Vector3 mirrorRotationOffset = Vector3.zero; // Góc xoay của gương so với Camera

        [Header("Scene Object")]
        public SceneObject[] objects;

        private void OnDrawGizmos()
        {
            Vector3 origin = transform.position;

            // Dùng Gizmos.matrix để Camera có thể xoay tự do trong không gian
            Gizmos.matrix = Matrix4x4.TRS(origin, transform.rotation, Vector3.one);
            Vector3 cubeSize = new Vector3(0.1f, 0.1f, 0.2f);
            Gizmos.DrawCube(-Vector3.forward * cubeSize.z / 2, cubeSize);
            Gizmos.DrawFrustum(Vector3.zero, fieldOfView, far, near, aspectRatio);
            Gizmos.matrix = Matrix4x4.identity; // Reset lại matrix về mặc định

            // Tính toán vị trí của View Plane dựa theo hướng nhìn (transform.forward)
            Vector3 viewPlanePos = origin + transform.forward * near;
            float viewPlaneHeight = near * Mathf.Tan(Mathf.Deg2Rad * fieldOfView / 2) * 2;
            float viewPlaneWidth = viewPlaneHeight * aspectRatio;
            Vector3 viewPlaneSize = new Vector3(viewPlaneWidth, viewPlaneHeight, 0.00001f);

            // Tính toán Quaternion và Vector của mặt gương (hỗ trợ xoay tự do)
            Quaternion mirrorRot = transform.rotation * Quaternion.Euler(mirrorRotationOffset);
            Vector3 mirrorNormal = mirrorRot * -Vector3.forward; // Pháp tuyến hướng về phía Camera
            Vector3 mirrorRight = mirrorRot * Vector3.right;
            Vector3 mirrorUp = mirrorRot * Vector3.up;

            if (isDrawPixel == false)
            {
                // Vẽ mặt View Plane / Mirror
                Gizmos.matrix = Matrix4x4.TRS(viewPlanePos, mirrorRot, Vector3.one);
                Gizmos.color = isMirror ? new Color(0.5f, 0.8f, 1f, 0.5f) : Color.white; // Gương có màu xanh nhạt
                Gizmos.DrawCube(Vector3.zero, viewPlaneSize);
                Gizmos.color = isMirror ? Color.cyan : Color.red;
                Gizmos.DrawWireCube(Vector3.zero, viewPlaneSize);
                Gizmos.matrix = Matrix4x4.identity;
            }
            else
            {
                int numberOfVerticalPixel = resolution;
                int numberOfHorizontalPixel = (int)(resolution * aspectRatio);

                for (int i = 0; i < numberOfHorizontalPixel; i++)
                {
                    for (int j = 0; j < numberOfVerticalPixel; j++)
                    {
                        float pixelHeight = viewPlaneHeight / numberOfVerticalPixel;
                        float pixelWidth = viewPlaneWidth / numberOfHorizontalPixel;

                        // Tọa độ Local trên mặt phẳng (chưa có vị trí Z)
                        float pixelLocalX = pixelWidth / 2 + pixelWidth * i - viewPlaneWidth / 2;
                        float pixelLocalY = pixelHeight / 2 + pixelHeight * j - viewPlaneHeight / 2;

                        // Tọa độ Global của pixel (nhân với vector Right và Up của gương)
                        Vector3 pixelPos = viewPlanePos + mirrorRight * pixelLocalX + mirrorUp * pixelLocalY;
                        Vector3 pixelSize = new Vector3(pixelWidth, pixelHeight, 0.00001f);

                        // Tia tới (Incident Ray): Từ mắt (origin) đến điểm trên gương
                        Vector3 incidentDirection = (pixelPos - origin).normalized;

                        Vector3 rayOrigin, rayDirection;

                        if (isMirror)
                        {
                            // LOGIC GƯƠNG: Bật ngược tia sáng (Phản xạ)
                            // Origin mới sẽ là điểm chạm trên mặt gương
                            rayOrigin = pixelPos;
                            rayDirection = Vector3.Reflect(incidentDirection, mirrorNormal);
                        }
                        else
                        {
                            // LOGIC BÌNH THƯỜNG: Bắn xuyên qua màn hình
                            rayOrigin = origin;
                            rayDirection = incidentDirection;
                        }

                        MyRay ray = new MyRay(rayOrigin, rayDirection);
                        HitData targetData = RayTrace(ray);

                        // Vẽ pixel với góc xoay của mặt gương (mirrorRot)
                        DrawPixelData(ray, targetData, pixelPos, pixelSize, mirrorRot);
                    }
                }
            }
        }

        public HitData RayTrace(MyRay ray)
        {
            HitData targetData = null;
            for (int k = 0; k < objects.Length; k++)
            {
                HitData data = objects[k].Intersect(ray);
                if (data != null)
                {
                    if (targetData == null) targetData = data;
                    else
                    {
                        if (data.distance < targetData.distance)
                        {
                            targetData = data;
                        }
                    }
                }
            }
            return targetData;
        }

        public void DrawPixelData(MyRay ray, HitData hitData, Vector3 pixelPos, Vector3 pixelSize, Quaternion rotation)
        {
            if (hitData != null) Gizmos.color = hitData.color;
            else Gizmos.color = Color.white;

            if (isShowRay)
            {
                ray.Draw();
                Gizmos.DrawSphere(pixelPos, pixelSize.x / 5f);
            }
            else
            {
                // Xoay pixel vuông góc với mặt gương hiện tại
                Gizmos.matrix = Matrix4x4.TRS(pixelPos, rotation, Vector3.one);
                Gizmos.DrawCube(Vector3.zero, pixelSize);
                Gizmos.color = Color.green;
                Gizmos.DrawWireCube(Vector3.zero, pixelSize);
                Gizmos.matrix = Matrix4x4.identity;
            }
        }
    }

    public class MyRay
    {
        public Vector3 origin;
        public Vector3 direction;

        public MyRay(Vector3 _origin, Vector3 _direction)
        {
            origin = _origin; direction = _direction;
        }

        public void Draw()
        {
            Gizmos.DrawRay(origin, direction * 5f);
        }
    }
}