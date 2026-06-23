<?php
// api/models/Appointment.php
require_once __DIR__ . '/Model.php';

class Appointment extends Model {
    public function getAll($staffId = null) {
        $sql = "
            SELECT a.*, c.name as client_name, c.phone as client_phone, s.name as service_name, st.name as staff_name 
            FROM appointments a
            JOIN clients c ON a.client_id = c.id
            JOIN services s ON a.service_id = s.id
            JOIN staff st ON a.staff_id = st.id
        ";
        
        $params = [];
        if ($staffId !== null) {
            $sql .= " WHERE a.staff_id = :staff_id";
            $params['staff_id'] = $staffId;
        }
        
        $sql .= " ORDER BY a.appointment_date DESC, a.start_time ASC";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function getTodayAppointments($staffId = null) {
        $date = date('Y-m-d');
        $sql = "
            SELECT a.*, c.name as client_name, c.phone as client_phone, s.name as service_name, s.duration_mins, st.name as staff_name 
            FROM appointments a
            JOIN clients c ON a.client_id = c.id
            JOIN services s ON a.service_id = s.id
            JOIN staff st ON a.staff_id = st.id
            WHERE a.appointment_date = :date
        ";
        
        $params = ['date' => $date];
        if ($staffId !== null) {
            $sql .= " AND a.staff_id = :staff_id";
            $params['staff_id'] = $staffId;
        }
        
        $sql .= " ORDER BY a.start_time ASC";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function create($clientId, $staffId, $serviceId, $date, $startTime, $clientType = 'pre-booked') {
        $this->db->beginTransaction();
        try {
            // 1. Fetch service duration
            $stmt = $this->db->prepare("SELECT duration_mins FROM services WHERE id = :id");
            $stmt->execute(['id' => $serviceId]);
            $duration = $stmt->fetchColumn();
            if (!$duration) {
                throw new Exception("Service not found");
            }

            // Calculate proposed end time
            $startTimestamp = strtotime("$date $startTime");
            $endTimestamp = $startTimestamp + ($duration * 60);
            $endTime = date('H:i:s', $endTimestamp);
            $startTimeFormatted = date('H:i:s', $startTimestamp);

            // 2. Check for slot conflict
            $stmt = $this->db->prepare("
                SELECT COUNT(*) FROM appointments 
                WHERE staff_id = :staff_id 
                  AND appointment_date = :date 
                  AND status != 'cancelled'
                  AND (:start_time < end_time AND :end_time > start_time)
            ");
            $stmt->execute([
                'staff_id' => $staffId,
                'date' => $date,
                'start_time' => $startTimeFormatted,
                'end_time' => $endTime
            ]);
            $conflictCount = $stmt->fetchColumn();

            if ($conflictCount > 0) {
                throw new Exception("Stylist is already booked for this time slot.");
            }

            // 3. Insert appointment
            $stmt = $this->db->prepare("
                INSERT INTO appointments (client_id, staff_id, service_id, appointment_date, start_time, end_time, status, client_type)
                VALUES (:client_id, :staff_id, :service_id, :date, :start_time, :end_time, 'upcoming', :client_type)
            ");
            $stmt->execute([
                'client_id' => $clientId,
                'staff_id' => $staffId,
                'service_id' => $serviceId,
                'date' => $date,
                'start_time' => $startTimeFormatted,
                'end_time' => $endTime,
                'client_type' => $clientType
            ]);
            
            $id = $this->db->lastInsertId();
            $this->db->commit();
            return $id;
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }
    }

    public function updateStatus($id, $status, $loggedById = null) {
        $this->db->beginTransaction();
        try {
            // Get appointment details to identify staff
            $stmt = $this->db->prepare("SELECT staff_id FROM appointments WHERE id = :id");
            $stmt->execute(['id' => $id]);
            $staffId = $stmt->fetchColumn();

            if (!$staffId) {
                throw new Exception("Appointment not found");
            }

            // Update status
            $stmt = $this->db->prepare("UPDATE appointments SET status = :status WHERE id = :id");
            $stmt->execute(['status' => $status, 'id' => $id]);

            // Sync staff availability based on status
            $staffStatus = 'available';
            if ($status === 'active') {
                $staffStatus = 'in_service';
            } elseif ($status === 'completed' || $status === 'cancelled') {
                $staffStatus = 'available';
            }

            $stmt = $this->db->prepare("UPDATE staff SET status = :status WHERE id = :id");
            $stmt->execute(['status' => $staffStatus, 'id' => $staffId]);

            $this->db->commit();

            // Auto-invoice if completed (performed outside the appointment update transaction to prevent nested PDO transaction error)
            if ($status === 'completed') {
                require_once __DIR__ . '/Invoice.php';
                (new Invoice())->createFromCompletedAppointment($id, $loggedById ?: 1);
            }

            return true;
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }
    }
}
