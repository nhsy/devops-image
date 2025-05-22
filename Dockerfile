ARG GCLOUD_VERSION=523.0.0
ARG PACKER_VERSION=1.12.0
ARG TERRAFORM_VERSION=1.12.1
ARG TERRAFORM_DOCS_VERSION=0.20.0
ARG TERRAGRUNT_VERSION=v0.80.1
ARG TFLINT_VERSION=0.57.0
ARG TFSEC_VERSION=1.28.14

FROM rockylinux:9 AS base

LABEL name=base-devops

ARG PACKER_VERSION
ARG TARGETARCH
ARG TERRAFORM_VERSION
ARG TERRAFORM_DOCS_VERSION
ARG TERRAGRUNT_VERSION
ARG TFLINT_VERSION
ARG TFSEC_VERSION

ENV CLOUDSDK_PYTHON=python3
ENV PATH /usr/lib/google-cloud-sdk/bin:$PATH
ENV TF_PLUGIN_CACHE_DIR=/opt/terraform/plugins-cache

COPY --chmod=755 scripts/*.sh /tmp/

RUN \
  set -x && \
  echo TARGETARCH: ${TARGETARCH} && \
  # Install Packages via Yum
  yum install -y \
    glibc-langpack-en \
    epel-release \
    && \
  \
  yum install -y --allowerasing \
    bash \
    bash-completion \
    curl \
    findutils \
    gcc \
    git \
    htop \
    jq \
    less \
    make \
    openssh-clients \
    procps-ng \
    python3 \
    python3-devel \
    sqlite-devel \
    tree \
    vim \
    wget \
    unzip \
    yum-utils \
    zip \
    zsh \
    && \
  # Update All Components
  yum update -y && \
  \
  python3 -m pip install --no-cache --upgrade -U pip && \
  python3 -m pip install --no-cache --upgrade wheel && \
  python3 -m pip install --no-cache --upgrade ansible && \
  python3 -m pip install --no-cache --upgrade ansible-lint[yamllint] && \
  python3 -m pip install --no-cache --upgrade mkdocs-material && \
  python3 -m pip install --no-cache --upgrade pre-commit && \
  \
  # Ansible Configuration
  mkdir -p /etc/ansible/roles && \
  wget -qO /etc/ansible/ansible.cfg https://raw.githubusercontent.com/ansible/ansible/devel/examples/ansible.cfg && \
  wget -qO /etc/ansible/hosts https://raw.githubusercontent.com/ansible/ansible/devel/examples/hosts && \
  \
  # Download, Install and Configure OhMyZsh
  sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
  sed -i 's/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"candy\"/g' ~/.zshrc && \
  \
  # Customisations \
  useradd devops && \
  \
  mkdir -p /opt/terraform/plugins-cache && \
  /tmp/10-zshrc.sh && \
  /tmp/20-bashrc.sh && \
  \
  # Cleanup \
  yum clean packages && \
  yum clean metadata && \
  yum clean all && \
  echo rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true && \
  rm -rf /root/.cache/pip/* && \
  rm -rf ~/.wget-hsts

RUN \
  set -x && \
  echo TARGETARCH: ${TARGETARCH} && \
  # Kubectl Configuration
  wget -qO /tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/${TARGETARCH}/kubectl && \
  chmod +x /tmp/kubectl && \
  mv /tmp/kubectl /usr/local/bin && \
  \
  # Install tfswitch and latest version of Terraform
  curl -sL https://raw.githubusercontent.com/warrensbox/terraform-switcher/release/install.sh | bash && \
  tfswitch -s ${TERRAFORM_VERSION} && \
  \
  # wget -qO /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip && \
  # unzip -q /tmp/terraform.zip -d /tmp && \
  # mv /tmp/terraform /usr/local/bin && \
  \
  wget -qO /tmp/terragrunt https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_${TARGETARCH} && \
  chmod +x /tmp/terragrunt && \
  mv /tmp/terragrunt /usr/local/bin && \
  \
  wget -qO /tmp/terraform-docs.tgz https://terraform-docs.io/dl/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${TARGETARCH}.tar.gz && \
  tar -xzf /tmp/terraform-docs.tgz -C /tmp/ && \
  chmod +x /tmp/terraform-docs && \
  mv /tmp/terraform-docs /usr/local/bin && \
  \
  wget -qO /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${TARGETARCH}.zip && \
  unzip -q /tmp/tflint.zip -d /tmp && \
  chmod +x /tmp/tflint && \
  mv /tmp/tflint /usr/local/bin && \
  \
  wget -qO /tmp/tfsec https://github.com/liamg/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-${TARGETARCH} && \
  chmod +x /tmp/tfsec && \
  mv /tmp/tfsec /usr/local/bin && \
  \
  wget -qO /tmp/packer.zip https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_${TARGETARCH}.zip && \
  unzip -q /tmp/packer.zip -d /tmp && \
  chmod +x /tmp/packer && \
  mv /tmp/packer /usr/local/bin && \
  \
  /tmp/30-unit-tests.sh && \
  \
  # Cleanup
  rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  rm -rf /root/.cache/pip/* && \
  find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true && \
  rm -rf ~/.wget-hsts

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#;;                                                                            ;;
#;;              ----==| G C P   D E V O P S   I M A G E |==----               ;;
#;;                                                                            ;;
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FROM base AS gcp-devops

LABEL name=gcp-devops

ARG GCLOUD_VERSION
ARG TARGETARCH

SHELL ["/bin/bash", "-c"]
RUN \
  set -x && \
  # google-cloud-sdk install and configuration
  if   [ "$TARGETARCH" = "amd64" ]; then \
    wget -qO /tmp/google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
    wget -qO /tmp/google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-arm.tar.gz; \
  fi && \
  tar -zxvf /tmp/google-cloud-sdk.tar.gz -C /usr/lib/ && \
  /usr/lib/google-cloud-sdk/install.sh --rc-path=/root/.zshrc --command-completion=true --path-update=true --quiet && \
  gcloud components install beta docker-credential-gcr gke-gcloud-auth-plugin --quiet && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud version && \
  \
  # Cleanup
  rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true && \
  rm -rf /root/.cache/pip/* && \
  rm -rf ~/.wget-hsts && \
  rm -rf /usr/lib/google-cloud-sdk/.install/.backup && \
  rm -rf /tmp/google-cloud-sdk.tar.gz

ENTRYPOINT ["/bin/zsh"]
WORKDIR /work

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#;;                                                                            ;;
#;;              ----==| A W S   D E V O P S   I M A G E |==----               ;;
#;;                                                                            ;;
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FROM base AS aws-devops

LABEL name=aws-devops

ARG TARGETARCH

SHELL ["/bin/bash", "-c"]
RUN \
  set -x && \
  \
  # AWS Python Requirements
  python3 -m pip install --upgrade --no-cache-dir -U crcmod && \
  python3 -m pip install --upgrade pytest && \
  python3 -m pip install --upgrade s3cmd && \
  python3 -m pip install --upgrade boto3 && \
  python3 -m pip install --upgrade cfn-lint && \
  python3 -m pip install --upgrade requests && \
  python3 -m pip install --upgrade bs4 && \
  python3 -m pip install --upgrade lxml && \
  \
  # AWS Configuration
  if [ "$TARGETARCH" = "amd64" ]; then \
    wget -qO /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip ; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
    wget -qO /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip ; \
  fi && \
  unzip -d /tmp /tmp/awscliv2.zip && \
  /tmp/aws/install && \
  \
  # AWS Session Manager Plugin Installation \
  if [ "$TARGETARCH" = "amd64" ]; then \
    yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm ; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
    yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm ; \
  fi && \
  \
  aws --version && \
  # Cleanup
  rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true && \
  rm -rf /root/.cache/pip/* && \
  rm -rf ~/.wget-hsts

ENTRYPOINT ["/bin/zsh"]
WORKDIR /work
