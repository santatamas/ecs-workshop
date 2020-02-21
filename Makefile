help: ## 
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-13s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: build-backend build-workers
	
build-backend: ## Builds the Docker image for the backend service
	cd backend; docker build . -t flask-backend:latest
	
build-workers: ## Builds the Docker image for the worker service
	cd workers; docker build . -t flask-worker:latest
	
create-repositories: ## Creates the required ECR repositories
	aws ecr create-repository --repository-name flask-backend
	aws ecr create-repository --repository-name flask-worker
	
env-vars:
    export BACKEND_REPO=$(aws ecr describe-repositories | jq -r .repositories[0].repositoryUri)
	export WORKER_REPO=$(aws ecr describe-repositories | jq -r .repositories[1].repositoryUri)
	export AWS_ACCESS_KEY_ID=$(aws configure get default.aws_access_key_id)
	export AWS_SECRET_ACCESS_KEY=$(aws configure get default.aws_secret_access_key)
	export AWS_SESSION_TOKEN=$(aws configure get default.aws_session_token)

push: push-backend push-worker
	
push-backend: ## Pushes the backend Docker image to the respective ECR repository
	$(aws ecr get-login --no-include-email --region eu-west-1)
	echo $(BACKEND_REPO)
	docker tag flask-backend:latest ${BACKEND_REPO}:latest
	docker push ${BACKEND_REPO}:latest
	
push-worker: ## Pushes the worker Docker image to the respective ECR repository
	$(aws ecr get-login --no-include-email --region eu-west-1)
	docker tag flask-worker:latest ${WORKER_REPO}:latest
	docker push ${WORKER_REPO}/flask-worker:latest
	
run-backend: ## Runs the backend image locally
	docker run -p 80:80 \
	-e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
	-e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
	-e AWS_DEFAULT_REGION=eu-west-1 \
	-e AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN} \
	-d flask-backend:latest