<?php
// api/controllers/AuthController.php
require_once __DIR__ . '/Controller.php';
require_once __DIR__ . '/../models/User.php';
require_once __DIR__ . '/../core/JWT.php';
require_once __DIR__ . '/../middlewares/AuthMiddleware.php';

class AuthController extends Controller {
    private $userModel;

    public function __construct() {
        $this->userModel = new User();
    }

    public function login() {
        $body = $this->getBody();
        $username = $body['username'] ?? '';
        $password = $body['password'] ?? '';

        if (empty($username) || empty($password)) {
            $this->json(['error' => 'Username and password are required'], 400);
        }

        $user = $this->userModel->authenticate($username, $password);
        if (!$user) {
            $this->json(['error' => 'Invalid username or password'], 401);
        }

        // Generate JWT token
        $token = JWT::encode([
            'id' => $user['id'],
            'username' => $user['username'],
            'role' => $user['role'],
            'name' => $user['name']
        ]);

        $this->json([
            'success' => true,
            'token' => $token,
            'user' => [
                'id' => $user['id'],
                'name' => $user['name'],
                'username' => $user['username'],
                'role' => $user['role']
            ]
        ]);
    }

    public function register() {
        // Only Admin can register new staff members!
        AuthMiddleware::handle(['admin']);
        
        $body = $this->getBody();
        $name = $body['name'] ?? '';
        $username = $body['username'] ?? '';
        $password = $body['password'] ?? '';
        $role = $body['role'] ?? ''; // admin, receptionist, stylist
        $commissionRate = floatval($body['commission_rate'] ?? 0.0);
        $commissionType = $body['commission_type'] ?? 'percentage';
        $specializations = $body['specializations'] ?? '';

        if (empty($name) || empty($username) || empty($password) || empty($role)) {
            $this->json(['error' => 'Name, username, password and role are required'], 400);
        }

        if (!in_array($role, ['admin', 'receptionist', 'stylist'])) {
            $this->json(['error' => 'Invalid role specified'], 400);
        }

        try {
            $userId = $this->userModel->register($name, $username, $password, $role, $commissionRate, $commissionType, $specializations);
            $this->json([
                'success' => true,
                'message' => 'Staff registered successfully',
                'user_id' => $userId
            ]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }

    public function getStaffList() {
        $headers = [];
        if (function_exists('getallheaders')) {
            $headers = getallheaders();
        }
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        if (empty($authHeader) && isset($_SERVER['HTTP_AUTHORIZATION'])) {
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
        }
        if (empty($authHeader) && isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
            $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        }

        if (!empty($authHeader)) {
            AuthMiddleware::handle(['admin', 'receptionist']);
            $staff = $this->userModel->getAllStaff();
            $this->json($staff);
        } else {
            $db = Database::getConnection();
            $stmt = $db->query("SELECT * FROM staff ORDER BY name ASC");
            $this->json($stmt->fetchAll());
        }
    }

    public function updateStatus() {
        $user = AuthMiddleware::handle(['stylist']);
        $body = $this->getBody();
        $status = $body['status'] ?? 'available';

        if (!in_array($status, ['available', 'off'])) {
            $this->json(['error' => 'Invalid status specified'], 400);
        }

        try {
            $db = Database::getConnection();
            $stmt = $db->prepare("UPDATE staff SET status = :status WHERE user_id = :user_id");
            $stmt->execute(['status' => $status, 'user_id' => $user['id']]);
            $this->json(['success' => true]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }

    public function updateStaff() {
        AuthMiddleware::handle(['admin']);
        $body = $this->getBody();
        $userId = intval($body['user_id'] ?? 0);
        $name = $body['name'] ?? '';
        $username = $body['username'] ?? '';
        $password = $body['password'] ?? null;
        $commissionRate = floatval($body['commission_rate'] ?? 0.0);
        $commissionType = $body['commission_type'] ?? 'percentage';
        $specializations = $body['specializations'] ?? '';

        if (empty($userId) || empty($name) || empty($username)) {
            $this->json(['error' => 'User ID, name, and username are required'], 400);
        }

        try {
            $this->userModel->updateStaffDetails($userId, $name, $username, $password, $commissionRate, $commissionType, $specializations);
            $this->json(['success' => true, 'message' => 'Staff updated successfully']);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }
}
