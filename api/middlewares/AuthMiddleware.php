<?php
// api/middlewares/AuthMiddleware.php
require_once __DIR__ . '/../core/JWT.php';

class AuthMiddleware {
    public static function handle($allowedRoles = []) {
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

        if (empty($authHeader)) {
            http_response_code(401);
            echo json_encode(['error' => 'Authorization token is required']);
            exit();
        }

        $parts = explode(' ', $authHeader);
        if (count($parts) !== 2 || strtolower($parts[0]) !== 'bearer') {
            http_response_code(401);
            echo json_encode(['error' => 'Invalid token format']);
            exit();
        }

        $token = $parts[1];
        $payload = JWT::decode($token);
        
        if (!$payload) {
            http_response_code(401);
            echo json_encode(['error' => 'Token is invalid or expired']);
            exit();
        }

        if (!empty($allowedRoles)) {
            $userRole = $payload['role'] ?? '';
            if (!in_array($userRole, $allowedRoles)) {
                http_response_code(403);
                echo json_encode(['error' => 'Access denied: Insufficient privileges']);
                exit();
            }
        }

        return $payload;
    }
}
