# 실습

### CodeBuild 및 Codepipeline 소개


### GitHub Repo Clone

- 실습에 필요한 자료를 GitHub를 통해 Clone

```yaml
$ git clone https://github.com/koDaegon/book-sample.git
```

### Cloudformation을 통해 기본 CI/CD 파이프라인 배포

- CFN/pipeline-setup.yaml 을 확인하여 Cloudformation을 통해 어떤 AWS 리소스가 배포되는지 확인
- 해당 파일을 복사하고 1-pipeline-base.yaml 파일을 생성하고 aws 환경에 배포
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%200.png)
    

- Stack Parameter에 base-stack의 Outputs 값을 참조하여 ArtifactBucket / PipelineServiceRoleArn  값을 입력
- RepositoryName에는 Sample Book application이 올라가게될 Repository 이름 입력 후 Cloudformation 배포
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%201.png)
    

- CloudFormation 배포가 완료 되었다면 Resource 탭으로 이동하여 생성된 리소스 확인
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%202.png)
    

- Codepipeline 으로 이동하여 파이프라인 기본 구성 확인
    
    <aside>
    💡 Codepipline 실패 원인??
    
    </aside>
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%203.png)
    

- Codepipeline 트리거를 위해 CodeCommit Repo 생성
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%204.png)
    

- Git remote를 CodeCommit Repo로 변경
    
    ```yaml
    $ git remote -v # 리모트 확인
    $ git remote remove origin #origin 리모트 삭제
    # CodeCommit remote 등록
    $ git remote add origin https://git-codecommit.ap-northeast-2.amazonaws.com/v1/repos/book-sample
    $ git remote -v # 리모트 확인
    ```
    
- CodeCommit Repo로 푸시
    
    ```yaml
    $ git push origin main
    ```
    
- Repo에 변경사항이 있기 때문에 Codepipeline이 자동으로 트리거 되어 동작
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%205.png)
    
- build_scripts 로 이동하여 buildspec.build.yaml에 미리 정의된 빌드 스크립트를 확인
    
    ```yaml
    version: 0.2
    env:
      shell: bash
      git-credential-helper: yes
      variables:
        REGION: "ap-northeast-2"
        IMAGE_TAG_KEY: "/book/sample/main/tag"
    phases:
      install:
        runtime-versions:
          java: corretto11
        commands:
          - apt-get update
          - apt-get install -y jq
      pre_build:
        commands:
          - echo "Print awscli version"
          - aws --version
          - export MY_ECR="${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-2.amazonaws.com/${ECR_REPO}"
          - echo "### SRC_VERISON-> ${CODEBUILD_RESOLVED_SOURCE_VERSION} | Logginging to ECR"
          - docker login --username AWS -p $(aws ecr get-login-password --region ${REGION}) ${MY_ECR}
          - export TAG=${CODEBUILD_RESOLVED_SOURCE_VERSION}
          - export TAG=$(echo $TAG | sed -e "s/\.//g"| tr '[:upper:]' '[:lower:]')
          - export TAG=$(echo "${TAG:0:8}")
          - export IMAGE_TAG="${TAG}"
          - export REPOSITORY_URI="${MY_ECR}"
          - echo "## TAG-> ${TAG}"
          - |
            echo "### Start App build ###"
            chmod +x ./gradlew 
            ./gradlew clean build  -x test --no-daemon
      build:
        commands:
          - |
            echo "### Building Container Image ###"
            echo $CODEBUILD_SRC_DIR
            echo Build started on `date`
            echo Building the Docker image...
            docker build -t $REPOSITORY_URI:latest ./
            docker images
            docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
    
          - |
            echo "### Pushing Container Image ###"
            docker push $REPOSITORY_URI:$IMAGE_TAG
          # - cat ./build_scripts/imageDef.json | envsubst > $CODEBUILD_SRC_DIR/imagedefinitions.json
          # - cat $CODEBUILD_SRC_DIR/imagedefinitions.json
      post_build:
        commands:
          - |
            echo "### Pushing Container Image Tag to SSM###"
            aws ssm put-parameter --name $IMAGE_TAG_KEY --value $IMAGE_TAG --overwrite
          - echo "${IMAGE_TAG}" >> build_output.txt
    artifacts:
      files:
        - build_output.txt
    cache:
      paths:
        - '/root/.gradle/caches/**/*'
    ```
    

- buildspec.deploy.yaml에 미리 정의된 배포 스크립트 확인
    
    ```yaml
    version: 0.2
    env:
      git-credential-helper: yes
      parameter-store:
        ASSUME_ROLE: /eks/role/arn
        IMAGE_TAG: /apprepo/image/main
        PUB_SUB_A: /base/pub/subnet/a
        PUB_SUB_C: /base/pub/subnet/c
    
    phases:
      install:
        commands:
          - echo "Install kubectl ..."
          - curl -LO "https://dl.k8s.io/release/v1.23.16/bin/linux/amd64/kubectl"
          - install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
          - curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
          - chmod 700 get_helm.sh
          - ./get_helm.sh
      pre_build:
        commands:
          - |
            echo "## Check aws cli and kubectl ##"
            aws --version
            kubectl version --client
            helm version
    
          - export MY_ECR="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO}"
          - echo ${IMAGE_TAG}
          - echo ${MY_ECR}
          - |
            export ASSUME_SESSION_NAME="codebuild-$(date +%s)"
    
            echo "ASSUME_ROLE_ARN=${ASSUME_ROLE}"
            aws sts assume-role --role-arn ${ASSUME_ROLE} --role-session-name ${ASSUME_SESSION_NAME} --output json > config.json
            
      build:
        commands:
          - |
            echo "Set up eks config ..."
            export AWS_ACCESS_KEY_ID_OLD=${AWS_ACCESS_KEY_ID}
            export AWS_SECRET_ACCESS_KEY_OLD=${AWS_SECRET_ACCESS_KEY}
            export AWS_SESSION_TOKEN_OLD=${AWS_SESSION_TOKEN}
    
            export AWS_ACCESS_KEY_ID=$(cat config.json | jq ".Credentials.AccessKeyId" | tr -d '"')
            export AWS_SECRET_ACCESS_KEY=$(cat config.json | jq ".Credentials.SecretAccessKey" | tr -d '"')
            export AWS_SESSION_TOKEN=$(cat config.json | jq ".Credentials.SessionToken" | tr -d '"')
            
            aws eks --region ap-northeast-2 update-kubeconfig --name kdaegon-sds-demo
    
          - |
            echo "### Deploy k8s manifest file"
            kubectl config current-context
            kubectl get pod -A  
            
            cd k8s-manifests
            cat deployment-template.yaml | envsubst > deployment.yaml
            cat ingress-template.yaml | envsubst > ingress.yaml
            
            cat deployment.yaml
            cat ingress.yaml
            
            kubectl apply -f deployment.yaml
            kubectl rollout status deployment deployment-demo -n demo
    
            kubectl apply -f svc.yaml
            kubectl apply -f ingress.yaml
          
          # - cd ${CODEBUILD_SRC_DIR}
    
          # - |
          #   echo "### Deploy helm chart"
            
          #   cd helm
          #   cat ./values-template.yaml | envsubst > ./demo/values.yaml
    
          #   cat ./demo/values.yaml
          #   helm upgrade --install -n test demo ./demo -f ./demo/values.yaml
          #   kubectl rollout status deployment deployment-demo -n test
    
      post_build:
        commands:
          - |
            cd ${CODEBUILD_SRC_DIR}
            echo "Deploy image tag : ${IMAGE_TAG}" > deploy_output.txt
    artifacts:
      files:
        - deploy_output.txt
    ```
    
- 파이프라인으로 이동하여 상태 확인
    - 실패….
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%206.png)
    
    - 로그 확인
        
        ```yaml
        Error Message: parameter does not exist: /eks/role/arn...
        ```
        
    
- Parameter Store로 이동하여 배포 스크립트에서 필요한 Param 생성
(/eks/role/arn , /base/pub/subnet/a , /base/pub/subnet/c)
- 이때 role arn은 EKS 클러스터를 생성한 c9에서 사용하는 role arn 입력
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%207.png)
    
- 
    
    
- Codepipeline을 다시 트리거 하여 Application을 배포
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%208.png)
    
- c9으로 이동하여 실제로 Book Namespace에 리소스가 잘 배포되었는지 확인
    
    ```yaml
    #Deployment 상태 확인
    $ kubectl get po -n book
    $ kubectl logs <pod_name> -n book
    
    #Ingress 상태 확인
    $ kubectl get ingress -n book
    $ kubectl describe ingress ingress-demo -n book
    ```
    
    - ingress 설정이 잘못 설정 됨.
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%209.png)
    
- ingress-tample.yaml 로 이동하여 배포 스크립트에서 치환 가능하게 변경 후 푸시
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%2010.png)
    
    ```yaml
    $ git add .
    $ git commit -m "Updated ingress"
    $ git push origin main
    ```
    

- 배포 완료 후 c9로 돌아가서 ingress 상태 확인
    
    ```yaml
    $ kubectl get ingress -n book
    ```
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%2011.png)
    
    <aside>
    💡 **만약 Application code 변경 없이 Deployment의 Replica 갯수만 바꾸고 싶다거나 혹은 ingress 의 설정만 변경 하고 싶다면??**
    
    </aside>
    

- 3분 정도 기다린 후 ingress로 접속하여 app이 정상적으로 배포 되었는지 확인 (/swagger-ui/index.html)
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/Untitled%2012.png)
