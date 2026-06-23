<?php
// api/index.php

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Autoload core files, controllers, and models manually for speed and reliability
require_once __DIR__ . '/core/Database.php';
require_once __DIR__ . '/core/JWT.php';
require_once __DIR__ . '/middlewares/AuthMiddleware.php';

require_once __DIR__ . '/models/Model.php';
require_once __DIR__ . '/models/User.php';
require_once __DIR__ . '/models/Appointment.php';
require_once __DIR__ . '/models/Client.php';
require_once __DIR__ . '/models/Service.php';
require_once __DIR__ . '/models/Product.php';
require_once __DIR__ . '/models/Invoice.php';
require_once __DIR__ . '/models/Expense.php';
require_once __DIR__ . '/models/Reconciliation.php';

require_once __DIR__ . '/controllers/Controller.php';
require_once __DIR__ . '/controllers/AuthController.php';
require_once __DIR__ . '/controllers/AppointmentController.php';
require_once __DIR__ . '/controllers/ClientController.php';
require_once __DIR__ . '/controllers/ServiceController.php';
require_once __DIR__ . '/controllers/POSController.php';
require_once __DIR__ . '/controllers/InventoryController.php';
require_once __DIR__ . '/controllers/ExpenseController.php';
require_once __DIR__ . '/controllers/ReconciliationController.php';

// Route action
$action = $_GET['action'] ?? '';
$method = $_SERVER['REQUEST_METHOD'];

switch ($action) {
    case 'login':
        if ($method === 'POST') {
            (new AuthController())->login();
        }
        break;

    case 'register':
        if ($method === 'POST') {
            (new AuthController())->register();
        }
        break;

    case 'staff':
        if ($method === 'GET') {
            (new AuthController())->getStaffList();
        } elseif ($method === 'POST') {
            (new AuthController())->register();
        }
        break;

    case 'staff_update':
        if ($method === 'POST') {
            (new AuthController())->updateStaff();
        }
        break;

    case 'staff_update_status':
        if ($method === 'POST') {
            (new AuthController())->updateStatus();
        }
        break;

    case 'dashboard':
        if ($method === 'GET') {
            (new AppointmentController())->getDashboard();
        }
        break;

    case 'appointments':
        if ($method === 'GET') {
            (new AppointmentController())->getAppointments();
        } elseif ($method === 'POST') {
            (new AppointmentController())->createAppointment();
        }
        break;

    case 'book_online':
        if ($method === 'POST') {
            (new AppointmentController())->createAppointment();
        }
        break;

    case 'appointments_today':
        if ($method === 'GET') {
            (new AppointmentController())->getTodayAppointments();
        }
        break;

    case 'appointments_update':
        if ($method === 'POST' || $method === 'PUT') {
            (new AppointmentController())->updateStatus();
        }
        break;

    case 'clients':
        if ($method === 'GET') {
            (new ClientController())->getClients();
        } elseif ($method === 'POST') {
            (new ClientController())->addClient();
        }
        break;

    case 'services':
        if ($method === 'GET') {
            (new ServiceController())->getServices();
        } elseif ($method === 'POST') {
            (new ServiceController())->addService();
        }
        break;

    case 'services_update':
        if ($method === 'POST') {
            (new ServiceController())->updateService();
        }
        break;

    case 'checkout':
        if ($method === 'POST') {
            (new POSController())->checkout();
        }
        break;

    case 'commission_report':
        if ($method === 'GET') {
            (new POSController())->getCommissionReport();
        }
        break;

    case 'stylist_payouts':
        if ($method === 'GET') {
            (new POSController())->getStylistPayouts();
        }
        break;

    case 'inventory':
        if ($method === 'GET') {
            (new InventoryController())->getInventory();
        } elseif ($method === 'POST') {
            (new InventoryController())->addProduct();
        }
        break;

    case 'inventory_stock':
        if ($method === 'POST') {
            (new InventoryController())->updateStock();
        }
        break;

    case 'inventory_alerts':
        if ($method === 'GET') {
            (new InventoryController())->getLowStockAlerts();
        }
        break;

    case 'expenses':
        if ($method === 'GET') {
            (new ExpenseController())->getExpenses();
        } elseif ($method === 'POST') {
            (new ExpenseController())->logExpense();
        }
        break;

    case 'reconciliation':
        if ($method === 'GET') {
            (new ReconciliationController())->getReconciliations();
        }
        break;

    case 'reconciliation_today':
        if ($method === 'GET') {
            (new ReconciliationController())->getTodayStatus();
        }
        break;

    case 'reconciliation_close':
        if ($method === 'POST') {
            (new ReconciliationController())->closeDrawer();
        }
        break;

    default:
        http_response_code(404);
        echo json_encode(['error' => 'Endpoint action not found']);
        break;
}
