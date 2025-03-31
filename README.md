# Development_Workshop

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
