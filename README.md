# Development_Workshop

Для второго задания:
minikube start --memory=4096 --cpus=2
eval $(minikube docker-env)
cd /path/to/your/project
curl -L https://istio.io/downloadIstio | sh -
cd istio-* && export PATH=$PWD/bin:$PATH && cd ..
chmod +x deploy.sh
./deploy.sh
# Далее — в другом окне
minikube tunnel
kubectl get svc -n istio-system istio-ingressgateway
# Для теста
curl http://127.0.0.1/
curl -X POST http://127.0.0.1/log -d '{"message": "Test"}' -H "Content-Type: application/json"
curl http://127.0.0.1/wrong

# Запуск:

1. Открываем Docker
2. В консоли выполняем команду `minikube start`
3. Затем `eval $(minikube docker-env)`
4. После в директории, где находится Dockerfile запустите `docker build -t stepan106/logger-app-python:latest .`
5. Делаем файл исполняемым `chmod +x deploy.sh`
6. Запуск  `./deploy.sh`

----
# Тестирование
```
curl http://localhost:8080/
curl http://localhost:8080/status
curl -X POST http://localhost:8080/log -d '{"message": "Test log"}'
curl http://localhost:8080/logs
  ```
