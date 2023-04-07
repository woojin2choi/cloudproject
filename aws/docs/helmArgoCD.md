# 실습

### ArgoCD 설정

- Argocd 설치 & 네임스페이스 생성
    
    ```
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```
    
- Argocd cli 설치
    
    ```
    cd ~/environment
    VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    sudo curl --silent --location -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
    
    sudo chmod +x /usr/local/bin/argocd
    ```
    
- argocd-server expose
    
    ```
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    ```
    
    ```
    export ARGOCD_SERVER=`kubectl get svc argocd-server -n argocd -o json | jq --raw-output .status.loadBalancer.ingress[0].hostname`
    echo $ARGOCD_SERVER
    ```
    
- Retrieve initial pwd for argoCD
    
    ```
    ARGO_PWD=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
    echo $ARGO_PWD
    ```
    
- ARGO_SERVER를 브라우저에서 오픈 하고 admin유저로 로그인
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%200.png)
    

- argoCD 접속 IAM User 생성
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%201.png)
    

- **HTTPS Git credentials for AWS CodeCommit 생성 후 Password 메모**
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%202.png)
    

### Helm Chart Repo 생성

- Helm chart repo를 위한 CodeCommit 레포 생성 후 [README.md](http://README.md) 파일 생성
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%203.png)
    

- 해당 레포를 c9 환경으로 clone
    
    ```yaml
    $ git clone https://git-codecommit.ap-northeast-2.amazonaws.com/v1/repos/book-sample-chart
    ```
    

- book-sample의 helm/book 폴더를 book-sample-chart로 복사 후 push
    
    ```yaml
    $ git add .
    $ git commit -m "Updated book-sample chart"
    $ git push origin main
    ```
    

<aside>
💡 **Chart Repo에 push도 했는데  다음 필요한 것은 무엇일까요???**

</aside>

### argoCD Chart Repo 연동

- argoCD로 이동하여 Setting > Repository로 이동 후 Connnect Repo를 통해 CodeCommit 레포 연동
- VIA HTTPS 방식으로 연결한 후 저장해놓은 username 및 password 입력
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%204.png)
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%205.png)
    

### argoCD app 생성

- 연결한 CodeCommit을 Repo URL로 입력한 후 argoCD App을 생성

![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%206.png)

### 파이프라인 수정

- 기존 배포 작업을 argoCD에서 대체하기 때문에 파이프라인 수정
    
    
    ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%207.png)
    

### 빌드 스크립트에 https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image tag 업데이트 추가

- 기존 빌드 스크립트에서  차트 레포에 Codebuild에서 https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image tag를 업데이트 할 수 있도록 스크립트를 변경
    
    ```yaml
    version: 0.2
    env:
      shell: bash
      git-credential-helper: yes
      parameter-store:
        PUB_SUB_A: /base/pub/subnet/a
        PUB_SUB_C: /base/pub/subnet/c
      variables:
        REGION: "ap-northeast-2"
        https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image_TAG_KEY: "/book/sample/main/tag"
        GIT_EMAIL: "codecommit/email"
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
          - export https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image_TAG="${TAG}"
          - export REPOSITORY_URI="${MY_ECR}"
          - echo "## TAG-> ${TAG}"
          - |
            echo "### Start App build ###"
            chmod +x ./gradlew 
            ./gradlew clean build  -x test --no-daemon
      build:
        commands:
          - |
            echo "### Building Container https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image ###"
            echo $CODEBUILD_SRC_DIR
            echo Build started on `date`
            echo Building the Docker https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image...
            docker build -t $REPOSITORY_URI:latest ./
            docker https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Images
            docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image_TAG
    
          - |
            echo "### Pushing Container https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image ###"
            docker push $REPOSITORY_URI:$https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image_TAG
          # - cat ./build_scripts/https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/ImageDef.json | envsubst > $CODEBUILD_SRC_DIR/https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Imagedefinitions.json
          # - cat $CODEBUILD_SRC_DIR/https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Imagedefinitions.json
      post_build:
        commands:
          - |
            echo "### Pushing Container https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image Tag to SSM###"
            aws ssm put-parameter --name $https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image_TAG_KEY --value $https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image_TAG --overwrite
          - echo "${https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image_TAG}" >> build_output.txt
          - git config --global --replace-all credential.helper '!aws codecommit credential-helper $@'
          - |
            echo "### Update value to manifest repo"
    
            git clone https://git-codecommit.ap-northeast-2.amazonaws.com/v1/repos/book-sample-chart
            cd book-sample-chart
            cd book
            cat values-template.yaml | envsubst > values.yaml
            cat values.yaml
            git status
            git config user.email "kdaegon@amazon.com"
            git config user.name "Daegon"
            git add .
            git commit -m "Updated https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image tag to $https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image_TAG"
            git log --oneline
            git remote -v
            git push -u origin main
    artifacts:
      files:
        - build_output.txt
    cache:
      paths:
        - '/root/.gradle/caches/**/*'
    ```
    

### argoCD에서 https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image tag 확인

- chart repo 및 SSM 그리고 argoCD 상에서 같은 이미지 태그를 사용중인지 확인
    - 차트 레포
        
        ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%208.png)
        
    - Parameter Store
        
        ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%209.png)
        
    - argoCD
        
        ![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/2-Untitled%2010.png)
