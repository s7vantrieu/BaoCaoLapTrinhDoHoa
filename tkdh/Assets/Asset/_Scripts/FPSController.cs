using UnityEngine;

[RequireComponent(typeof(CharacterController))]
public class FPSController : MonoBehaviour
{
    [Header("Movement Settings")]
    public float walkingSpeed = 5.0f;
    public float runningSpeed = 8.0f;
    public float jumpSpeed = 6.0f;
    
    [Header("Gravity & Fly Mode (Noclip)")]
    public bool useGravity = true; // Tick bật/tắt trọng lực
    public float gravity = 20.0f;
    public float flySpeed = 10.0f; // Tốc độ khi bay
    public KeyCode toggleGravityKey = KeyCode.G; // Phím G để bật/tắt bay

    [Header("Look Settings")]
    public Camera playerCamera;
    [Tooltip("Độ nhạy của chuột (Mouse Sensitivity)")]
    public float mouseSensitivity = 2.0f; 
    public float lookXLimit = 85.0f;

    private CharacterController characterController;
    private Vector3 moveDirection = Vector3.zero;
    private float rotationX = 0;

    void Start()
    {
        characterController = GetComponent<CharacterController>();

        // Khóa chuột vào giữa màn hình
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    void Update()
    {
        // 1. CHUYỂN ĐỔI CHẾ ĐỘ BAY / ĐI BỘ (Nhấn phím G)
        if (Input.GetKeyDown(toggleGravityKey))
        {
            useGravity = !useGravity;
            // Reset lại lực rơi khi tắt trọng lực để không bị vọt đi
            if (!useGravity) moveDirection.y = 0; 
        }

        // 2. XỬ LÝ GÓC NHÌN (Sử dụng Mouse Sensitivity)
        rotationX += -Input.GetAxis("Mouse Y") * mouseSensitivity;
        rotationX = Mathf.Clamp(rotationX, -lookXLimit, lookXLimit);
        
        playerCamera.transform.localRotation = Quaternion.Euler(rotationX, 0, 0);
        transform.rotation *= Quaternion.Euler(0, Input.GetAxis("Mouse X") * mouseSensitivity, 0);

        // 3. XỬ LÝ DI CHUYỂN
        bool isRunning = Input.GetKey(KeyCode.LeftShift);

        if (useGravity)
        {
            // CHẾ ĐỘ ĐI BỘ BÌNH THƯỜNG (Có trọng lực)
            Vector3 forward = transform.TransformDirection(Vector3.forward);
            Vector3 right = transform.TransformDirection(Vector3.right);

            float curSpeedX = (isRunning ? runningSpeed : walkingSpeed) * Input.GetAxis("Vertical");
            float curSpeedY = (isRunning ? runningSpeed : walkingSpeed) * Input.GetAxis("Horizontal");
            
            float movementDirectionY = moveDirection.y; 
            moveDirection = (forward * curSpeedX) + (right * curSpeedY);

            // Xử lý nhảy
            if (Input.GetButtonDown("Jump") && characterController.isGrounded)
            {
                moveDirection.y = jumpSpeed;
            }
            else
            {
                moveDirection.y = movementDirectionY;
            }

            // Áp dụng trọng lực
            if (!characterController.isGrounded)
            {
                moveDirection.y -= gravity * Time.deltaTime;
            }
        }
        else
        {
            // CHẾ ĐỘ BAY LƯỢN (Không trọng lực)
            // Lấy hướng forward của Camera thay vì của cơ thể để bay thẳng theo hướng nhìn
            Vector3 flyDirection = playerCamera.transform.forward * Input.GetAxis("Vertical") 
                                 + playerCamera.transform.right * Input.GetAxis("Horizontal");

            // Nhấn E để bay lên thẳng đứng, Q để bay xuống
            if (Input.GetKey(KeyCode.E)) flyDirection += Vector3.up;
            if (Input.GetKey(KeyCode.Q)) flyDirection += Vector3.down;

            float currentFlySpeed = isRunning ? runningSpeed * 2f : flySpeed;
            
            // Ghi đè moveDirection hoàn toàn (không lưu lực hút)
            moveDirection = flyDirection.normalized * currentFlySpeed;
        }

        // 4. THỰC THI DI CHUYỂN
        characterController.Move(moveDirection * Time.deltaTime);
    }
}