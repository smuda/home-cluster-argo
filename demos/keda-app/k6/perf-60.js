import http from 'k6/http'
import { check, sleep } from 'k6'

export let options = {
    thresholds: {
        http_req_duration: ['p(95)<500', 'p(99)<1500'],
    },
    scenarios: {
        contacts: {
            executor: 'ramping-vus',
            //startVUs: 10,
            stages: [
                { duration: '90s', target: 60 },
                { duration: '3m', target: 60 },
            ],
            gracefulRampDown: '30s',
        }
    }
}

export default function () {
    //const data = { username: 'username', password: 'password' }
    //let res = http.post('app-keda-app.apps.okd4.example.com', data)
    let res = http.get('http://app-keda-app.apps.okd4.example.com')

    check(res, { 'success login': (r) => r.status === 200 })

    sleep(1)
}
