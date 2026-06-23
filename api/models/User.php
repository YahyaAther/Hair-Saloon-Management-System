<?php
// api/models/User.php
require_once __DIR__ . '/Model.php';

class User extends Model {
    public function authenticate($username, $password) {
        $stmt = $this->db->prepare("SELECT * FROM users WHERE username = :username LIMIT 1");
        $stmt->execute(['username' => $username]);
        $user = $stmt->fetch();
        
        if ($user && password_verify($password, $user['password_hash'])) {
            unset($user['password_hash']);
            return $user;
        }
        return null;
    }

    public function register($name, $username, $password, $role, $commission_rate = 0.0, $commission_type = 'percentage', $specializations = '') {
        $this->db->beginTransaction();
        try {
            // Check username unique
            $stmt = $this->db->prepare("SELECT id FROM users WHERE username = :username");
            $stmt->execute(['username' => $username]);
            if ($stmt->fetch()) {
                throw new Exception("Username already exists");
            }

            $hash = password_hash($password, PASSWORD_BCRYPT);
            $stmt = $this->db->prepare("
                INSERT INTO users (name, username, password_hash, role, commission_rate, commission_type)
                VALUES (:name, :username, :hash, :role, :commission_rate, :commission_type)
            ");
            $stmt->execute([
                'name' => $name,
                'username' => $username,
                'hash' => $hash,
                'role' => $role,
                'commission_rate' => $commission_rate,
                'commission_type' => $commission_type
            ]);
            $userId = $this->db->lastInsertId();

            // If user is stylist, insert into staff table
            if ($role === 'stylist') {
                $stmt = $this->db->prepare("
                    INSERT INTO staff (user_id, name, role, specializations, status)
                    VALUES (:user_id, :name, :role, :specializations, 'available')
                ");
                $stmt->execute([
                    'user_id' => $userId,
                    'name' => $name,
                    'role' => 'Stylist',
                    'specializations' => $specializations
                ]);
            }

            $this->db->commit();
            return $userId;
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }
    }

    public function getAllStaff() {
        $stmt = $this->db->query("
            SELECT u.id as user_id, u.name, u.username, u.role, u.commission_rate, u.commission_type, 
                   s.id as staff_id, s.specializations, s.status
            FROM users u
            LEFT JOIN staff s ON u.id = s.user_id
            ORDER BY u.role ASC, u.name ASC
        ");
        return $stmt->fetchAll();
    }

    public function updateStaffDetails($userId, $name, $username, $password = null, $commissionRate = 0.0, $commissionType = 'percentage', $specializations = '') {
        $this->db->beginTransaction();
        try {
            // Update users table
            if (!empty($password)) {
                $hash = password_hash($password, PASSWORD_BCRYPT);
                $stmt = $this->db->prepare("
                    UPDATE users 
                    SET name = :name, username = :username, password_hash = :hash, 
                        commission_rate = :commission_rate, commission_type = :commission_type
                    WHERE id = :id
                ");
                $stmt->execute([
                    'name' => $name,
                    'username' => $username,
                    'hash' => $hash,
                    'commission_rate' => $commissionRate,
                    'commission_type' => $commissionType,
                    'id' => $userId
                ]);
            } else {
                $stmt = $this->db->prepare("
                    UPDATE users 
                    SET name = :name, username = :username, 
                        commission_rate = :commission_rate, commission_type = :commission_type
                    WHERE id = :id
                ");
                $stmt->execute([
                    'name' => $name,
                    'username' => $username,
                    'commission_rate' => $commissionRate,
                    'commission_type' => $commissionType,
                    'id' => $userId
                ]);
            }

            // Update staff table if user is stylist
            $stmt = $this->db->prepare("SELECT role FROM users WHERE id = :id");
            $stmt->execute(['id' => $userId]);
            $user = $stmt->fetch();
            if ($user && $user['role'] === 'stylist') {
                // Check if entry exists in staff
                $stmt = $this->db->prepare("SELECT id FROM staff WHERE user_id = :user_id");
                $stmt->execute(['user_id' => $userId]);
                if ($stmt->fetch()) {
                    $stmt = $this->db->prepare("
                        UPDATE staff 
                        SET name = :name, specializations = :specializations
                        WHERE user_id = :user_id
                    ");
                    $stmt->execute([
                        'name' => $name,
                        'specializations' => $specializations,
                        'user_id' => $userId
                    ]);
                } else {
                    $stmt = $this->db->prepare("
                        INSERT INTO staff (user_id, name, role, specializations, status)
                        VALUES (:user_id, :name, 'Stylist', :specializations, 'available')
                    ");
                    $stmt->execute([
                        'user_id' => $userId,
                        'name' => $name,
                        'specializations' => $specializations
                    ]);
                }
            }

            $this->db->commit();
            return true;
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }
    }
}
