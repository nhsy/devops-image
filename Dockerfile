ARG GCLOUD_VERSION=383.0.1
ARG PACKER_VERSION=1.8.0
ARG TERRAGRUNT_VERSION=0.36.6
ARG TFLINT_VERSION=0.35.0
ARG TFSEC_VERSION=1.17.0

FROM rockylinux:latest AS base

LABEL name=base-devops

ARG PACKER_VERSION
ARG TARGETARCH
ARG TERRAGRUNT_VERSION
ARG TFLINT_VERSION
ARG TFSEC_VERSION

ENV CLOUDSDK_PYTHON=python3
ENV PATH /usr/lib/google-cloud-sdk/bin:$PATH
ENV TF_PLUGIN_CACHE_DIR=/opt/terraform/plugins-cache

COPY scripts/*.sh /tmp/

RUN \
  set -x && \
  echo TARGETARCH: ${TARGETARCH} && \
  # Install Packages via Yum
  yum install -y \
    glibc-langpack-en \
    epel-release \
    && \
  \
  yum install -y \
    # ansible \
    bash \
    bash-completion \
    curl \
    findutils \
    git \
    jq \
    less \
    make \
    openssh-clients \
    python3 \
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
  python3 -m pip install --upgrade -U pip  && \
  python3 -m pip install --upgrade wheel  && \
  python3 -m pip install --upgrade ansible && \
  python3 -m pip install --upgrade ansible-lint[yamllint] && \
  python3 -m pip install --upgrade mkdocs-material && \
  python3 -m pip install --upgrade paramiko && \
  python3 -m pip install --upgrade pre-commit && \
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
   mkdir -p ${TF_PLUGIN_CACHE_DIR} && \
  . /tmp/10-zshrc.sh && \
  . /tmp/20-bashrc.sh && \
  \
  # Cleanup \
  yum clean packages && \
  yum clean metadata && \
  yum clean all && \
  rm -rf /tmp/* && \
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
  # Install tfswitch and Install latest version of Terraform
  curl -sL https://raw.githubusercontent.com/warrensbox/terraform-switcher/release/install.sh | bash && \
  tfswitch --latest && \
  \
  wget -qO /tmp/terragrunt https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${TARGETARCH} && \
  chmod +x /tmp/terragrunt && \
  mv /tmp/terragrunt /usr/local/bin && \
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
  # Cleanup
  rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  rm -rf /root/.cache/pip/* && \
  find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true && \
  rm -rf ~/.wget-hsts && \
  \
  # Confirm Versions
  ansible --version && \
  echo $SHELL && \
  kubectl version --client && \
  python3 --version && \
  #python3.8 --version && \
  terraform version && \
  terragrunt -version && \
  tflint --version && \
  tfsec --version && \
  packer version

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#;;                                                                            ;;
#;;              ----==| G C P   D E V O P S   I M A G E |==----               ;;
#;;                                                                            ;;
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


FROM base AS gcp-devops

LABEL name=gcp-devops

ARG GCLOUD_VERSION
ARG PACKER_VERSION
ARG TARGETARCH
ARG TERRAGRUNT_VERSION
ARG TFLINT_VERSION
ARG TFSEC_VERSION
ARG PYTHON_VERSION

SHELL ["/bin/bash", "-c"]
RUN \
  set -x && \
  # GCP / gcloud Configuration
  if   [ "$TARGETARCH" = "amd64" ]; then \
    wget -qO /tmp/google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
    wget -qO /tmp/google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-arm.tar.gz; \
  fi && \
  tar -zxvf /tmp/google-cloud-sdk.tar.gz -C /usr/lib/ && \
  /usr/lib/google-cloud-sdk/install.sh --rc-path=/root/.zshrc --command-completion=true --path-update=true --quiet && \
  gcloud components install beta docker-credential-gcr --quiet && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  rm -rf /usr/lib/google-cloud-sdk/.install/.backup && \
  rm -rf /tmp/google-cloud-sdk.tar.gz && \
  \
  # Cleanup
  rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true && \
  rm -rf /root/.cache/pip/* && \
  rm -rf ~/.wget-hsts && \
  # Confirm Versions
  gcloud --version

ENTRYPOINT ["/bin/zsh"]
WORKDIR /work