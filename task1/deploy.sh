#!/bin/bash
set -e

DOCKER_IMAGE="stepan106/logger-app-python:latest"

echo "==== Развертывание распределенной системы логирования ===="


if ! kubectl get namespace istio-system > /dev/null 2>&1; then
  echo "1. Установка Istio Service Mesh (демо профиль)..."
  istioctl install --set profile=demo -y
fi

# Включаем injection для default namespace
kubectl label namespace default istio-injection=enabled --overwrite


echo "2. Сборка Docker образа и отправка на registry..."
docker login
docker build -t $DOCKER_IMAGE .
docker push $DOCKER_IMAGE

echo "3. Создание ConfigMap..."
kubectl apply -f k8s/config.yaml

echo "4. Развертывание тестового Pod..."
kubectl apply -f k8s/pod.yaml

echo "5. Ожидание готовности Pod..."
kubectl wait --for=condition=Ready pod/app-pod --timeout=60s

echo "6. Тестирование API тестового Pod..."
kubectl port-forward pod/app-pod 8080:8080 &
sleep 2
curl http://localhost:8080/
curl http://localhost:8080/status
curl -X POST http://localhost:8080/log -d '{"message": "Test log"}' -H "Content-Type: application/json"
curl http://localhost:8080/logs
# Завершаем port-forward
kill %1 || true

echo "7. Развертывание Deployment с 3 репликами..."
kubectl apply -f k8s/deployment.yaml

echo "8. Ожидание готовности Deployment..."
kubectl rollout status deployment/app-deployment

echo "9. Развертывание Service для балансировки нагрузки..."
kubectl apply -f k8s/service.yaml

echo "10. Развертывание DaemonSet для сбора логов..."
kubectl apply -f k8s/daemonset.yaml

echo "11. Развертывание CronJob для архивирования логов..."
kubectl apply -f k8s/cronjob.yaml

echo "12. Применяем Istio Gateway и виртуальный сервис..."
kubectl apply -f k8s/istio/gateway.yaml
kubectl apply -f k8s/istio/virtualservice.yaml
kubectl apply -f k8s/istio/destinationrule-app.yaml

echo "==== Система успешно развернута! ===="
echo "Для тестирования через Istio IngressGateway:"
echo "  minikube tunnel   # В новом окне!"
echo "  kubectl get svc -n istio-system istio-ingressgateway"
echo "  curl http://127.0.0.1/"
echo "  curl -X POST http://127.0.0.1/log -d '{\"message\":\"Test attempt\"}' -H 'Content-Type: application/json'"
echo "  curl http://127.0.0.1/wrong"
echo "Для просмотра логов агентов:"
echo "  kubectl logs -l name=log-agent"
echo "Для просмотра результатов архивирования (после срабатывания CronJob):"
echo "  kubectl get pods | grep log-archiver"
echo "  kubectl logs <pod-name>"
