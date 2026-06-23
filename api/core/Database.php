<?php
// api/core/Database.php

class Database {
    private static $pdo = null;

    public static function getConnection() {
        if (self::$pdo === null) {
            $db_file = 'C:/Users/HP/Downloads/saloon.db';
            $is_new_db = !file_exists($db_file);
            
            try {
                $dsn = "sqlite:$db_file";
                $options = [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                ];
                self::$pdo = new PDO($dsn, null, null, $options);
                self::$pdo->exec("PRAGMA foreign_keys = ON;");
                self::$pdo->exec("PRAGMA journal_mode = WAL;");
                self::$pdo->exec("PRAGMA busy_timeout = 5000;");

                if ($is_new_db) {
                    self::createTables();
                }
            } catch (PDOException $e) {
                http_response_code(500);
                echo json_encode(['error' => 'Database connection failed: ' . $e->getMessage()]);
                exit();
            }
        }
        return self::$pdo;
    }

    private static function createTables() {
        $pdo = self::$pdo;
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                role TEXT NOT NULL, -- admin, receptionist, stylist
                commission_rate REAL DEFAULT 0.0,
                commission_type TEXT DEFAULT 'percentage', -- percentage, fixed
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS services (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                description TEXT,
                duration_mins INTEGER NOT NULL,
                price REAL NOT NULL,
                category TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS staff (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NULL,
                name TEXT NOT NULL,
                role TEXT NOT NULL,
                specializations TEXT,
                status TEXT DEFAULT 'available', -- available, in_service, off
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS clients (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT,
                phone TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                total_spent REAL DEFAULT 0.0,
                last_visit DATE
            );

            CREATE TABLE IF NOT EXISTS appointments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id INTEGER,
                staff_id INTEGER,
                service_id INTEGER,
                appointment_date DATE NOT NULL,
                start_time TIME NOT NULL,
                end_time TIME NOT NULL,
                status TEXT DEFAULT 'upcoming', -- upcoming, active, completed, cancelled
                client_type TEXT DEFAULT 'pre-booked', -- pre-booked, walk-in
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(client_id) REFERENCES clients(id),
                FOREIGN KEY(staff_id) REFERENCES staff(id),
                FOREIGN KEY(service_id) REFERENCES services(id)
            );

            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                description TEXT,
                price REAL NOT NULL,
                stock_quantity REAL NOT NULL, -- supports fractional deductions for consumption
                category TEXT NOT NULL, -- salon_consumption, retail_sale
                min_stock_alert REAL NOT NULL
            );

            CREATE TABLE IF NOT EXISTS invoices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id INTEGER NULL,
                logged_by INTEGER NOT NULL,
                payment_method TEXT NOT NULL, -- cash, digital
                payment_status TEXT DEFAULT 'paid', -- paid, unpaid
                total_amount REAL NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(client_id) REFERENCES clients(id),
                FOREIGN KEY(logged_by) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS invoice_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                invoice_id INTEGER NOT NULL,
                item_type TEXT NOT NULL, -- service, product
                item_id INTEGER NOT NULL, -- refers to services or products
                stylist_id INTEGER NULL, -- stylist performing service or selling product
                quantity INTEGER NOT NULL,
                price REAL NOT NULL,
                commission_paid REAL DEFAULT 0.0,
                FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
                FOREIGN KEY(stylist_id) REFERENCES staff(id)
            );

            CREATE TABLE IF NOT EXISTS expenses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                category TEXT NOT NULL,
                amount REAL NOT NULL,
                description TEXT,
                expense_date DATE NOT NULL,
                logged_by INTEGER NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(logged_by) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS cash_reconciliation (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                reconciliation_date DATE UNIQUE NOT NULL,
                opening_cash REAL NOT NULL,
                total_cash_sales REAL NOT NULL,
                digital_payments REAL NOT NULL,
                logged_expenses REAL NOT NULL,
                closing_balance REAL NOT NULL,
                status TEXT DEFAULT 'open', -- open, closed
                closed_by INTEGER NULL,
                closed_at DATETIME NULL,
                FOREIGN KEY(closed_by) REFERENCES users(id)
            );
        ");

        // Seed data
        $admin_pwd = password_hash('adminpass', PASSWORD_BCRYPT);
        $recep_pwd = password_hash('receppass', PASSWORD_BCRYPT);
        $emma_pwd = password_hash('emmapass', PASSWORD_BCRYPT);
        $david_pwd = password_hash('davidpass', PASSWORD_BCRYPT);

        $pdo->exec("
            INSERT INTO users (name, username, password_hash, role, commission_rate, commission_type) VALUES 
            ('System Administrator', 'admin', '$admin_pwd', 'admin', 0.0, 'percentage'),
            ('Sarah Receptionist', 'recep', '$recep_pwd', 'receptionist', 0.0, 'percentage'),
            ('Emma Watson', 'emma', '$emma_pwd', 'stylist', 40.0, 'percentage'),
            ('David Lee', 'david', '$david_pwd', 'stylist', 30.0, 'percentage');

            INSERT INTO services (name, description, duration_mins, price, category) VALUES 
            ('Women''s Haircut', 'Includes wash & blowdry', 60, 85.00, 'Haircuts & Styling'),
            ('Men''s Haircut', 'Includes wash & style', 45, 45.00, 'Haircuts & Styling'),
            ('Blowout', 'Wash & premium blowout', 45, 55.00, 'Haircuts & Styling'),
            ('Full Color', 'Single process color', 90, 120.00, 'Color & Highlights'),
            ('Partial Highlights', 'Crown & front frame', 120, 145.00, 'Color & Highlights'),
            ('Balayage', 'Hand-painted highlights', 180, 210.00, 'Color & Highlights');

            INSERT INTO staff (user_id, name, role, specializations, status) VALUES 
            (3, 'Emma Watson', 'Master Stylist', 'Colorist, Balayage', 'available'),
            (4, 'David Lee', 'Senior Barber', 'Men''s Cuts, Fades', 'available');

            INSERT INTO products (name, description, price, stock_quantity, category, min_stock_alert) VALUES 
            ('Premium Hair Wax', 'Strong hold styling wax', 18.00, 50.0, 'retail_sale', 10.0),
            ('Argan Styling Oil', 'Hydrating organic argan oil', 35.00, 30.0, 'retail_sale', 5.0),
            ('Dye Developer 20V', 'Fractional professional developer', 0.00, 150.0, 'salon_consumption', 20.0),
            ('Shampoo Gallon', 'Backbar salon shampoo', 0.00, 12.5, 'salon_consumption', 3.0);

            INSERT INTO clients (name, email, phone, last_visit, total_spent) VALUES 
            ('Amanda Smith', 'amanda.s@example.com', '+1 (555) 234-5678', '2026-06-10', 850.00),
            ('John Doe', 'john.doe@example.com', '+1 (555) 345-6789', '2026-06-12', 210.00);
        ");

        $date = date('Y-m-d');
        $pdo->exec("
            INSERT INTO appointments (client_id, staff_id, service_id, appointment_date, start_time, end_time, status, client_type) VALUES 
            (1, 1, 6, '$date', '10:00:00', '13:00:00', 'active', 'pre-booked'),
            (2, 2, 2, '$date', '13:30:00', '14:15:00', 'upcoming', 'pre-booked');

            INSERT INTO cash_reconciliation (reconciliation_date, opening_cash, total_cash_sales, digital_payments, logged_expenses, closing_balance, status) VALUES 
            ('$date', 200.00, 0.0, 0.0, 0.0, 200.00, 'open');
        ");
    }
}
