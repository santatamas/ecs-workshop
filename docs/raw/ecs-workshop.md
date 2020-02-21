# ECS Service discovery workshop
In this workshop you’re going to manually create and deploy 2 services into **ECS Fargate**, and configure **ECS Service Discovery** using Cloudmap so they can find and talk to each other.

The **backend** polls the service discovery API for information about the available namespaces, services and instances, and renders the result in an HTML page.

The **worker** application is a simple webserver, which responds to a _GET '\\'_ with a message.

## Prerequisites
Clone the project git repository in your **Cloud9** environment.
```bash
git clone https://github.com/santatamas/ecs-workshop.git
cd ~/environment/ecs-workshop
```

### Creating the ECR repositories
First, create 2 docker image repositories for our backend and worker images.
```bash
aws ecr create-repository --repository-name flask-backend
aws ecr create-repository --repository-name flask-worker
```

### Setting up the required environment variables
You need to export a few environment variables for later use.
```bash
export BACKEND_REPO=$(aws ecr describe-repositories | \
jq -r .repositories[0].repositoryUri)
export WORKER_REPO=$(aws ecr describe-repositories | \
jq -r .repositories[1].repositoryUri)
```

### Building the container images
Next, you'll build the docker images for the worker, and backend applications.
```bash
cd backend; docker build . -t flask-backend:latest; cd ..
cd workers; docker build . -t flask-worker:latest; cd ..
```

### Tagging & pushing the images to ECR
As a final step, let's tag the images, and push them to the ECR repositories you just created.
```bash
$(aws ecr get-login --no-include-email --region eu-west-1)
docker tag flask-backend:latest ${BACKEND_REPO}:latest
docker push ${BACKEND_REPO}:latest
docker tag flask-worker:latest ${WORKER_REPO}:latest
docker push ${WORKER_REPO}:latest
```
---
#### [OPTIONAL] Running the backend application from Cloud9
It's possible to run the **backend** application straight from your Cloud9 environment. By default, the hosted zone in Route53 is not associated with your Cloud9 VPC, hence the private DNS name resolution for your services will fail.

To fix this, open your AWS Management Console, and navigate to Route53.
Select your hosted zone (should be called **service.**), and from the VPC ID dropdown on the right hand side, select the VPC of your Cloud9 environment.
![alt text](http://127.0.0.1:8080/img_1.png "Route53 settings")
Finally, click on _Associate New VPC_.

Export your AWS credentials to environment variables
```bash
export AWS_ACCESS_KEY_ID=$(aws configure get default.aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get default.aws_secret_access_key)
export AWS_SESSION_TOKEN=$(aws configure get default.aws_session_token)
```

Run the following command in your Cloud9 Terminal to run the **backend** docker image locally:
```bash
docker run -p 80:80 \
-e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
-e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
-e AWS_DEFAULT_REGION=eu-west-1 \
-e AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN} \
-d flask-backend:latest
```
Now you should be able to access the website within your Cloud9 environment, without having to deploy it to ECS.
```bash
curl localhost
```
---

### Allowing the ECS Task execution role to access the Service Discovery API
Our backend application will access the Service Discovery API to retrieve a list of namespaces, services and instances. The Task Execution role we created during the previous workshop does not provide access to this API, so we'll have to extend it.

- Open IAM, and select the Task Execution role starting with **container-demo-ECSTaskExecutionRole**
![alt text](http://127.0.0.1:8080/img_9.png "Configure container parameters")

- Select the existing policy, and update it with the following JSON
```javascript
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "servicediscovery:*",
                "logs:CreateLogStream",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:GetAuthorizationToken",
                "logs:PutLogEvents",
                "ecr:BatchCheckLayerAvailability"
            ],
            "Resource": "*"
        }
    ]
}
```

### Creating a new ECS Task Definition for the backend
- Open your AWS Management Console, and navigate to Amazon ECS.
- Create a new Task Definition
![alt text](http://127.0.0.1:8080/img_2.png "Create new Task Definition")

- Select **FARGATE**, and click _Next step_
- Next, name your definition _backend_, and re-use the task and execution roles from your previous workshop. For task memory and CPU, use 1GB and 0.5 vCPU.
![alt text](http://127.0.0.1:8080/img_3.png "Configure task")

- Add a new container definition, and use the URI of the **backend** docker image from your ECR repository.
![alt text](http://127.0.0.1:8080/img_4.png "Configure container parameters")

- Finally, click "Create" to create the Task definition.

### Creating a new ECS Service for the backend
- Open Amazon ECS, and display the Clusters
![alt text](http://127.0.0.1:8080/img_5.png "Clusters")

- Click _Create_ to create a new Service
- Use the values shown below, then click _Next step_
![alt text](http://127.0.0.1:8080/img_6.png "New Service")

- Use the existing VPC and subnet for the service. Make sure to select a public subnet, you'll have to be able to access the container from your browser.
![alt text](http://127.0.0.1:8080/img_7.png "VPC settings")

- Use the existing Service Discovery namespace (created during the previous workshop)
![alt text](http://127.0.0.1:8080/img_8.png "Service Discovery settings")

- Finish the setup, and create the service (Next->Next->Finish)
- Open the public IP of the container, and you should see the running application
![alt text](http://127.0.0.1:8080/img_10.png "Running backend application")

### Creating a new ECS Task Definition for the worker nodes
- Create a new Task Definition using the previous steps. Use the name "worker", and use the URI of the **worker** docker image from your ECR repository.

### Creating a new ECS Service for the workers
- Create a new service
- Use the settings shown below. Please note that we specified 3 running instances for this service, to test load balancing.
![alt text](http://127.0.0.1:8080/img_11.png "Worker service settings")

- Use the VPC settings shown below. This time, try to specify a different subnet for the worker instances.
![alt text](http://127.0.0.1:8080/img_12.png "Worker service VPC")

- Use the existing Service Discovery Namespace (created during the previous workshop)
![alt text](http://127.0.0.1:8080/img_13.png "Worker Service Discovery")

- Refresh the **backend** application in your browser to see the newly discovered worker service. The application also sends an HTTP request to the service, and displays the response.
![alt text](http://127.0.0.1:8080/img_14.png "Backend application")

## Summary
In this exercise you:
- Set up ECR repositories, built and pushed docker images
- Created ECS Fargate Task Definitions for the **backend** and **worker** applications
- Deployed the Task Definitions to services
- Used service discovery to communicate with the deployed services
