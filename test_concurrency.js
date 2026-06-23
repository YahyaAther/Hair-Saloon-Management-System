// test_concurrency.js
// Simulates simultaneous database writes to verify SQLite WAL mode and retry concurrency logic.

const URL_LOGIN = 'http://localhost:8000/api/index.php?action=login';
const URL_EXPENSES = 'http://localhost:8000/api/index.php?action=expenses';

async function runTests() {
    console.log('1. Authenticating as admin to obtain JWT...');
    
    try {
        const loginRes = await fetch(URL_LOGIN, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username: 'admin', password: 'adminpass' })
        });
        
        if (!loginRes.ok) {
            console.error('Authentication failed!');
            return;
        }
        
        const loginData = await loginRes.json();
        const token = loginData.token;
        console.log('Authenticated successfully.');

        console.log('\n2. Initiating 10 simultaneous concurrent write operations...');
        const promises = [];
        
        for (let i = 1; i <= 10; i++) {
            promises.push(
                fetch(URL_EXPENSES, {
                    method: 'POST',
                    headers: { 
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${token}`
                    },
                    body: JSON.stringify({
                        category: 'Salon Supplies',
                        amount: 10.00,
                        description: `Concurrency Test Write #${i}`
                    })
                }).then(async res => {
                    const text = await res.text();
                    return { status: res.status, text };
                }).catch(err => {
                    return { status: 'ERROR', text: err.message };
                })
            );
        }

        const results = await Promise.all(promises);
        
        console.log('\nResponse Outputs:');
        let successCount = 0;
        let failCount = 0;
        
        results.forEach((res, idx) => {
            if (res.status === 200) {
                successCount++;
                console.log(`Transaction #${idx + 1}: SUCCESS (200 OK)`);
            } else {
                failCount++;
                console.log(`Transaction #${idx + 1}: FAILED (Status: ${res.status}) - ${res.text}`);
            }
        });

        console.log(`\nConcurrency Test Summary:`);
        console.log(`- Successes: ${successCount}/10`);
        console.log(`- Failures: ${failCount}/10`);
        
        if (failCount === 0) {
            console.log('PASS: SQLite WAL and busy_timeout handled concurrent transactions without lock errors!');
        } else {
            console.log('FAIL: Database locking occurred.');
        }

    } catch (e) {
        console.error('Test script error:', e.message);
    }
}

runTests();
