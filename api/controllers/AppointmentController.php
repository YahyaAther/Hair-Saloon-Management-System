<?php
// api/controllers/AppointmentController.php
require_once __DIR__ . '/Controller.php';
require_once __DIR__ . '/../models/Appointment.php';
require_once __DIR__ . '/../models/Client.php';
require_once __DIR__ . '/../models/Service.php';
require_once __DIR__ . '/../middlewares/AuthMiddleware.php';
require_once __DIR__ . '/../core/Database.php';

class AppointmentController extends Controller {
    private $appointmentModel;
    private $clientModel;

    public function __construct() {
        $this->appointmentModel = new Appointment();
        $this->clientModel = new Client();
    }

    public function getDashboard() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        
        $db = Database::getConnection();
        $date = date('Y-m-d');
        
        try {
            // Get today's total invoice revenue
            $stmt = $db->prepare("
                SELECT SUM(total_amount) as total_revenue 
                FROM invoices 
                WHERE date(created_at) = :date
            ");
            $stmt->execute(['date' => $date]);
            $totalRevenue = $stmt->fetchColumn() ?: 0.0;

            // Get today's appointments count
            $stmt = $db->prepare("SELECT COUNT(*) FROM appointments WHERE appointment_date = :date");
            $stmt->execute(['date' => $date]);
            $appointmentsCount = $stmt->fetchColumn() ?: 0;

            // Get total clients
            $totalClients = $db->query("SELECT COUNT(*) FROM clients")->fetchColumn() ?: 0;

            // Get today's appointments list
            $todayAppointments = $this->appointmentModel->getTodayAppointments();

            $this->json([
                'totalRevenue' => $totalRevenue,
                'appointmentsToday' => $appointmentsCount,
                'totalClients' => $totalClients,
                'todayAppointmentsList' => $todayAppointments
            ]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 500);
        }
    }

    public function getAppointments() {
        $user = AuthMiddleware::handle(['admin', 'receptionist', 'stylist']);
        
        $staffId = null;
        if ($user['role'] === 'stylist') {
            $db = Database::getConnection();
            $stmt = $db->prepare("SELECT id FROM staff WHERE user_id = :user_id");
            $stmt->execute(['user_id' => $user['id']]);
            $staffId = $stmt->fetchColumn();
            
            if (!$staffId) {
                $this->json(['error' => 'Stylist profile not found'], 404);
            }
        }

        $appointments = $this->appointmentModel->getAll($staffId);
        $this->json($appointments);
    }

    public function getTodayAppointments() {
        $user = AuthMiddleware::handle(['admin', 'receptionist', 'stylist']);
        
        $staffId = null;
        if ($user['role'] === 'stylist') {
            $db = Database::getConnection();
            $stmt = $db->prepare("SELECT id FROM staff WHERE user_id = :user_id");
            $stmt->execute(['user_id' => $user['id']]);
            $staffId = $stmt->fetchColumn();
        }

        $appointments = $this->appointmentModel->getTodayAppointments($staffId);
        $this->json($appointments);
    }

    public function createAppointment() {
        $body = $this->getBody();
        
        $clientName = $body['client_name'] ?? '';
        $clientEmail = $body['client_email'] ?? '';
        $clientPhone = $body['client_phone'] ?? '';
        $staffId = $body['staff_id'] ?? null;
        $serviceId = $body['service_id'] ?? null;
        $date = $body['date'] ?? '';
        $time = $body['time'] ?? '';
        $clientType = $body['client_type'] ?? 'pre-booked';

        if (empty($clientName) || empty($staffId) || empty($serviceId) || empty($date) || empty($time)) {
            $this->json(['error' => 'Missing required appointment fields'], 400);
        }

        try {
            $clientId = $this->clientModel->findOrCreate($clientName, $clientEmail, $clientPhone);
            $appointmentId = $this->appointmentModel->create($clientId, $staffId, $serviceId, $date, $time, $clientType);
            
            $this->json([
                'success' => true,
                'message' => 'Appointment created successfully',
                'appointment_id' => $appointmentId
            ]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }

    public function updateStatus() {
        $user = AuthMiddleware::handle(['admin', 'receptionist', 'stylist']);
        
        $body = $this->getBody();
        $id = $body['id'] ?? null;
        $status = $body['status'] ?? '';

        if (!$id || empty($status)) {
            $this->json(['error' => 'Appointment ID and status are required'], 400);
        }

        if (!in_array($status, ['upcoming', 'active', 'completed', 'cancelled'])) {
            $this->json(['error' => 'Invalid status specified'], 400);
        }

        try {
            $this->appointmentModel->updateStatus($id, $status, $user['id']);
            $this->json(['success' => true, 'message' => 'Appointment status updated successfully']);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }
}
