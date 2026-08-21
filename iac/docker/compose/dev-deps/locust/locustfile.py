from locust import HttpUser, SequentialTaskSet, task, between
import json
import uuid
import random

class UserBehavior(SequentialTaskSet):

    def on_start(self):
        # load example env values (Postman-shaped JSON)
        with open('/mnt/locust/locust.env.example.json') as f:
            self.env_vars = json.load(f)['values']
        
        self.base_url = self.get_env_variable('url')
        self.client_token = None
        self.operator_token = None
        self.order_uuid = None
        self.unc = None
        self.amount = None
        self.offer_uuid = None

    def get_env_variable(self, key):
        return next(item['value'] for item in self.env_vars if item['key'] == key)

    def set_env_variable(self, key, value):
        for item in self.env_vars:
            if item['key'] == key:
                item['value'] = value
                break
        else:
            self.env_vars.append({"key": key, "value": value})

    @task
    def login_client(self):
        # client login (first request)
        url = f"{self.base_url}/api/login"
        data = {
            "client_id": "shop-app",
            "client_secret": "CHANGE_ME",
            "grant_type": "password",
            "username": self.get_env_variable('login_client'),
            "password": self.get_env_variable('password_client')
        }
        with self.client.post(url, data=data, catch_response=True) as response:
            if response.status_code == 200:
                response_json = response.json()
                self.client_token = response_json['access_token']
                self.set_env_variable("client_token", self.client_token)
                response.success()
            else:
                response.failure(f"Failed to login: {response.status_code}")

    @task
    def create_order(self):
        # create an order
        if self.client_token is None:
            self.login_client()
        
        url = f"{self.base_url}/client/api/v1/orders"
        headers = {"Authorization": f"Bearer {self.client_token}"}
        self.order_uuid = str(uuid.uuid4())
        self.set_env_variable("order_uuid", self.order_uuid)

        # generate UNC and amount
        self.unc = f"000{random.randint(100000, 999999)}/{random.randint(1000, 9999)}/{random.randint(1000, 9999)}/{random.randint(0, 9)}/{random.randint(0, 9)}"
        self.amount = random.randint(10000, 50000)
        self.set_env_variable("unc", self.unc)
        self.set_env_variable("amount", self.amount)

        data = {
            "order_uuid": self.order_uuid,
            "type_id": 1,
            "unc": self.unc,
            "country_id": 1,
            "amount": self.amount,
            "currency_id": 43,
            "service_id": 1,
            "swift_id": 1,
            "is_lc": False,
            "comment": "created via Locust",
            "exchange_rate": 0
        }
        with self.client.post(url, json=data, headers=headers, catch_response=True) as response:
            if response.status_code == 201:
                response.success()
            else:
                response.failure(f"Failed to create order: {response.status_code}")

    @task
    def get_order(self):
        # fetch the order by UUID
        if self.order_uuid is None:
            self.create_order()

        url = f"{self.base_url}/client/api/v1/orders/{self.order_uuid}"
        headers = {"Authorization": f"Bearer {self.client_token}"}
        with self.client.get(url, headers=headers, catch_response=True) as response:
            if response.status_code == 200:
                response_json = response.json()
                operator_uuid = response_json['result']['operator_uuid']
                self.handle_operator_uuid(operator_uuid)
                response.success()
            else:
                response.failure(f"Failed to get order: {response.status_code}")

    def handle_operator_uuid(self, operator_uuid):
        # pick operator login from the fixture UUID
        if operator_uuid == "00000000-0000-4000-8000-000000000011":
            self.set_env_variable("login_operator", "operator1")
            self.set_env_variable("password_operator", "CHANGE_ME")
        elif operator_uuid == "00000000-0000-4000-8000-000000000012":
            self.set_env_variable("login_operator", "operator2")
            self.set_env_variable("password_operator", "CHANGE_ME")
        elif operator_uuid == "00000000-0000-4000-8000-000000000013":
            self.set_env_variable("login_operator", "operator3")
            self.set_env_variable("password_operator", "CHANGE_ME")
        else:
            # unmatched UUID uses the default operator login
            self.set_env_variable("login_operator", "operator")
            self.set_env_variable("password_operator", "CHANGE_ME")

    @task
    def login_operator(self):
        # operator login
        url = f"{self.base_url}/api/login"
        data = {
            "client_id": "shop-app",
            "client_secret": "CHANGE_ME",
            "grant_type": "password",
            "username": self.get_env_variable('login_operator'),
            "password": self.get_env_variable('password_operator')
        }
        with self.client.post(url, data=data, catch_response=True) as response:
            if response.status_code == 200:
                response_json = response.json()
                self.operator_token = response_json['access_token']
                self.set_env_variable("operator_token", self.operator_token)
                response.success()
            else:
                response.failure(f"Failed to login as operator: {response.status_code}")

    @task
    def open_order(self):
        # open the order as operator
        if self.operator_token is None:
            self.login_operator()

        url = f"{self.base_url}/operator/api/v1/orders/{self.order_uuid}"
        headers = {"Authorization": f"Bearer {self.operator_token}"}
        with self.client.get(url, headers=headers, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Failed to open order: {response.status_code}")

    @task
    def create_offer(self):
        # create an offer
        if self.operator_token is None:
            self.login_operator()

        url = f"{self.base_url}/operator/api/v1/offers"
        headers = {"Authorization": f"Bearer {self.operator_token}"}
        data = {
            "agent_uuid": self.get_env_variable('agent_uuid'),
            "order_uuid": self.order_uuid,
            "agent_commission": 8
        }
        with self.client.post(url, json=data, headers=headers, catch_response=True) as response:
            if response.status_code == 200:
                response_json = response.json()
                self.offer_uuid = response_json['result']
                self.set_env_variable("offer_uuid", self.offer_uuid)
                response.success()
            else:
                response.failure(f"Failed to create offer: {response.status_code}")

    @task
    def update_order_to_intermediate_status(self):
        # move the order to an intermediate status (example: 4)
        if self.client_token is None:
            self.login_client()

        url = f"{self.base_url}/client/api/v1/orders/{self.order_uuid}/status"
        headers = {"Authorization": f"Bearer {self.client_token}"}
        data = {
            "status": 4  # example intermediate status
        }
        with self.client.put(url, json=data, headers=headers, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Failed to update order status to intermediate: {response.status_code}")
                print(f"Response body: {response.text}")

    @task
    def close_order(self):
        # close the order after the intermediate status
        if self.operator_token is None:
            self.login_operator()

        url = f"{self.base_url}/operator/api/v1/orders/{self.order_uuid}/close"
        headers = {
            "Authorization": f"Bearer {self.operator_token}",
            "Content-Type": "application/json"
        }
        data = {
            "status": 5,
            "amount": self.amount,
            "currency_id": 43,
            "comment_close": "closed via Locust",
            "exchange_rate": 0.18
        }
        with self.client.put(url, json=data, headers=headers, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Failed to close order: {response.status_code}")
                print(f"Response body: {response.text}")

    @task
    def get_all_orders(self):
        # list orders
        if self.client_token is None:
            self.login_client()

        url = f"{self.base_url}/client/api/v1/orders?page=1&page_size=100"
        headers = {"Authorization": f"Bearer {self.client_token}"}
        with self.client.get(url, headers=headers, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Failed to get all orders: {response.status_code}")


class WebsiteUser(HttpUser):
    tasks = [UserBehavior]
    wait_time = between(1, 3)
