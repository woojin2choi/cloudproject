# 실습

### Event Engine 접속

### 베이스 Cloudformation 배포

- 0-base-setup.yaml 파일을 통해 실습에 필요한 기본적인 리소스 VPC, S3, IAM role등을 배포합니다.

![Untitled](https://github.com/koDaegon/book-sample/blob/1aa70009590b9f5a94f4413747a20972ec995a73/docs/Image/base-cfn.png)


### Cloud9 Workspace 생성

- [참조](https://catalog.us-east-1.prod.workshops.aws/workshops/9c0aa9ab-90a9-44a6-abe1-8dff360ae428/ko-KR/30-setting/100-aws-cloud9)

### GitHub Clone
    ```
    git clone https://github.com/koDaegon/book-sample.git
    ```


### Cloud9 Workspace에  필요한 툴 설치

- kubectl 설치
    
    ```
    sudo curl -o /usr/local/bin/kubectl  \
       https://s3.us-west-2.amazonaws.com/amazon-eks/1.23.16/2022-10-31/bin/linux/amd64/kubectl
    
    sudo chmod +x /usr/local/bin/kubectl
    kubectl version --short
    
    ```
    
- awscli 업데이트
    
    ```
    curl "<https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip>" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    aws --version
    
    ```
    
- jq 설치
    
    ```
    sudo yum -y install jq gettext bash-completion moreutils
    
    ```
    
- eksctl 설치
    
    ```
    curl --silent --location "<https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$>(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    
    sudo mv -v /tmp/eksctl /usr/local/bin
    
    ```
    
- helm 설치
    
    ```
    brew install helm
    # curl -sSL <https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3> | bash
    
    ```
    
- kubectl 자동완성 설정
    
    ```
    kubectl completion bash >>  ~/.bash_completion
    . /etc/profile.d/bash_completion.sh
    . ~/.bash_completion
    
    ```
    
- brew 설치(optional)
    
    ```
    /bin/bash -c "$(curl -fsSL <https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh>)"
    
    #After install
    #test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
    #test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    #test -r ~/.bash_profile && echo "eval \\"\\$($(brew --prefix)/bin/brew shellenv)\\"" >>~/.bash_profile
    #echo "eval \\"\\$($(brew --prefix)/bin/brew shellenv)\\"" >>~/.profile
    
    ```
    
- K9S 설치(Optional)
    
    ```
    brew install derailed/k9s/k9s
    
    ```
    

### Cloud9 IAM role mapping

- Admin role로 Cloud9 instance IAM 역할 수정
- 임시 자격증명 비활성화
    
    > Cloud9에 임시로 매핑된 임시 자격증명이 아니라 매핑한 롤을 Cloud9의 자격 증명으로 사용하기 위해 임시로 매핑된 자격증명을 비활성화해야 함.
    > 
    
    ```
    aws cloud9 update-environment  --environment-id $C9_PID --managed-credentials-action DISABLE
    rm -vf ${HOME}/.aws/credentials
    
    ```
    
- IAM Role 확인
    
    ```
    aws sts get-caller-identity
    
    ```
    
- Account ID, Region 설정
    
    ```
    export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
    export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
    export AZS=($(aws ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName' --output text --region $AWS_REGION))
    
    ```
    
- Bash profile 저장
    
    ```
    echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
    echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
    echo "export AZS=(${AZS[@]})" | tee -a ~/.bash_profile
    aws configure set default.region ${AWS_REGION}
    aws configure get default.region
    
    ```
    

### eksctl을 통한 EKS Cluster 생성

- eks/eks-cluster 파일음 참조하여 eksctl을 통해 클러스터 배포
- Public Subnet 값 반드시 확인 후 배포
    
    ```
    apiVersion: eksctl.io/v1alpha5
    kind: ClusterConfig
    
    metadata:
      name: eks-demo # 생성할 EKS 클러스터명
      region: ap-northeast-2 # 클러스터를 생성할 리전
      version: "1.23"
    
    vpc:
      subnets:
        private:
          ap-northeast-2a: { id: <Private-Subnet-id-1> }
          ap-northeast-2b: { id: <Private-Subnet-id-2> }
    
    managedNodeGroups:
      - name: node-group # 클러스터의 노드 그룹명
        instanceType: m5.large # 클러스터 워커 노드의 인스턴스 타입
        desiredCapacity: 2 # 클러스터 워커 노드의 갯수
        volumeSize: 20  # 클러스터 워커 노드의 EBS 용량 (단위: GiB)
        privateNetworking: true
        ssh:
          enableSsm: true
        iam:
          withAddonPolicies:
            imageBuilder: true # Amazon ECR에 대한 권한 추가
            albIngress: true  # albIngress에 대한 권한 추가
            cloudWatch: true # cloudWatch에 대한 권한 추가
            autoScaler: true # auto scaling에 대한 권한 추가
            ebs: true # EBS CSI Driver에 대한 권한 추가
    
    cloudWatch:
      clusterLogging:
        enableTypes: ["*"]
    
    iam:
      withOIDC: true
    ```
    
- create cluster with eksctl
    
    ```
    eksctl create cluster -f eks-cluster.yaml
    
    ```
    
- test the cluster
    
    ```
    kubectl get nodes
    
    ```
    

### AWS Load Balancer Controller 생성

- [참조](https://catalog.us-east-1.prod.workshops.aws/workshops/9c0aa9ab-90a9-44a6-abe1-8dff360ae428/ko-KR/60-ingress-controller/100-launch-alb)
- IAM OIDC 생성
    - Service account에 iam role 을 사용하기 위해 IAM OIDC provider를 생성해야함
    
    ```
    eksctl utils associate-iam-oidc-provider \\
    --region ${AWS_REGION} \\
    --cluster ${CLUSTER_NAME} \\
    --approve
    
    ```
    
    - 확인
    
    ```
    aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text
    
    ```
    
- Service Account IAM policy 생성
    
    ```
    curl -o iam_policy.json <https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.3.0/docs/install/iam_policy.json>
    aws iam create-policy \\
        --policy-name AWSLoadBalancerControllerIAMPolicy \\
        --policy-document file://iam_policy.json
    
    ```
    
- Service Account 생성 for LB Controller
    
    ```
    eksctl create iamserviceaccount \\
        --cluster ${CLUSTER_NAME} \\
        --namespace kube-system \\
        --name aws-load-balancer-controller \\
        --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \\
        --override-existing-serviceaccounts \\
        --approve
    TargetGroupBinging CRDs 설치
    [https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/guide/targetgroupbinding/targetgroupbinding/](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/guide/targetgroupbinding/targetgroupbinding/)
    ```
    
- EKS repo 를 helm에 추가
    
    ```
    helm repo add eks <https://aws.github.io/eks-charts>
    
    ```
    
- AWS Load Balancer controller 클 클러스터에 추가
    
    ```
    kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml
    ```
    
- Load balancer controller yaml 파일을 다운로드
    
    ```
    wget https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.4/v2_4_4_full.yaml
    ```
    
- 다운로드 받은 파일에 대해서 cluster-name을 편집합니다.
    
    ```
    spec:
        containers:
        - args:
            - --cluster-name=eks-demo # 생성한 클러스터 이름을 입력
            - --ingress-class=alb
            image: amazon/aws-alb-ingress-controller:v2.4.4
    ```
    
- manifest 파일에서 Service account부분은 삭제합니다.
    
    ```yaml
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      labels:
        app.kubernetes.io/component: controller
        app.kubernetes.io/name: aws-load-balancer-controller
      name: aws-load-balancer-controller
      namespace: kube-system
    ```
    
- AWS Load Balancer controller 파일을 배포합니다.
    
    ```yaml
    kubectl apply -f v2_4_4_full.yaml	
    ```
    
- LB 컨트롤러 정상 배포 확인
    
    ```yaml
    kubectl get deployment -n kube-system aws-load-balancer-controllereiifccrcfvvgvrhdrfvhkkffecdnrgttiijbebecterv
    ```
    
- Sample-App. 배포 (선택사항)

```
---
apiVersion: v1
kind: Namespace
metadata:
  name: game-2048
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: game-2048
  name: deployment-2048
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: app-2048
  replicas: 2
  template:
    metadata:
      labels:
        app.kubernetes.io/name: app-2048
    spec:
      containers:
      - image: public.ecr.aws/l6m2t8p7/docker-2048:latest
        imagePullPolicy: Always
        name: app-2048
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  namespace: game-2048
  name: service-2048
spec:
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
  type: NodePort
  selector:
    app.kubernetes.io/name: app-2048
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: game-2048
  name: ingress-2048
  annotations:
    alb.ingress.kubernetes.io/ip-address-type: ipv4
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/subnets: <public_subnet_id_1>, <public_subnet_id_2>
    alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/backend-protocol: HTTP
spec:
  rules:
    - http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: service-2048
              port:
                number: 80
```

- 위의 파일을 복사 한 후 원하는 파일명으로 워크스페이스에 생성 후  sample app 배포
    
    ```yaml
     kubectl apply -f <filename>.yaml
    ```
    

---
