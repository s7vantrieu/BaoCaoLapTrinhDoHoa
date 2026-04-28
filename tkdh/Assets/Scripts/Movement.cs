using UnityEngine;
namespace tkdh
{
    public class Movement : MonoBehaviour
    {
        [Header("Cài đặt di chuyển")]
        public float moveSpeed = 5f; // Tốc độ di chuyển, có thể chỉnh trong Inspector

        private Rigidbody rb;
        private Vector3 movementInput;

        void Start()
        {
            // Lấy component Rigidbody đã gắn trên Cube
            rb = GetComponent<Rigidbody>();
        }

        void Update()
        {
            // Nhận tín hiệu từ người chơi (WASD hoặc Phím mũi tên)
            // Dùng GetAxisRaw để di chuyển dứt khoát hơn (trả về -1, 0, hoặc 1)
            float moveX = Input.GetAxisRaw("Horizontal");
            float moveZ = Input.GetAxisRaw("Vertical");

            // Gom tín hiệu lại thành một Vector3. Hướng y = 0 vì ta không bay lên.
            // Dùng .normalized để tránh lỗi đi chéo nhanh hơn đi thẳng.
            movementInput = new Vector3(moveX, 0f, moveZ).normalized;
        }

        // Luôn xử lý các logic liên quan đến Rigidbody và Vật lý trong FixedUpdate
        void FixedUpdate()
        {
            // Tính toán vận tốc mới
            Vector3 newVelocity = movementInput * moveSpeed;

            // Giữ nguyên vận tốc rơi của trục Y (nếu lỡ Cube rơi xuống rìa Ground)
            newVelocity.y = rb.velocity.y;

            // Gán vận tốc mới cho Rigidbody
            rb.velocity = newVelocity;
        }
    }
}
