

FROM ubuntu:24.04 AS base

LABEL name=base-devops

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV AQUA_ROOT_DIR=/root/.local/share/aquaproj-aqua
ENV PATH=/usr/lib/google-cloud-sdk/bin:$AQUA_ROOT_DIR/bin:$PATH
ENV TF_PLUGIN_CACHE_DIR=/opt/terraform/plugins-cache
ENV AQUA_GLOBAL_CONFIG=/etc/aqua/aqua.yaml


COPY --chmod=755 scripts/*.sh /tmp/
COPY aqua.yaml /etc/aqua/aqua.yaml

RUN \
  set -x && \
  echo TARGETARCH: ${TARGETARCH} && \
  # Update and install packages via APT
  apt-get update && \
  apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  gnupg \
  htop \
  jq \
  openssh-client \
  procps \
  python3-pip \
  python3-venv \
  tree \
  vim \
  wget \
  unzip \
  zip \
  zsh \
  && \
  # Upgrade pip and install Python packages (consolidated)
  python3 -m pip install --no-cache-dir --break-system-packages --upgrade pre-commit && \
  \
  # Download, Install and Configure OhMyZsh
  sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
  sed -i 's/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"candy\"/g' ~/.zshrc && \
  \
  # Install Aqua
  curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v3.0.1/aqua-installer | bash -s -- -v v2.31.0 && \
  \
  # Install tools via Aqua
  /root/.local/share/aquaproj-aqua/bin/aqua -c /etc/aqua/aqua.yaml i -a && \
  \
  # Verify installation immediately
  test -f /root/.local/share/aquaproj-aqua/bin/terraform || (echo "Terraform not found after install!" && ls -R /root/.local && exit 1) && \
  \
  # Customisations
  useradd -m devops && \
  mkdir -p /opt/terraform/plugins-cache && \
  /tmp/10-zshrc.sh && \
  /tmp/20-bashrc.sh && \
  \
  # Run Unit Tests during build to ensure tools are ready
  PATH=/root/.local/share/aquaproj-aqua/bin:$PATH /tmp/30-unit-tests.sh && \

  \
  # Cleanup
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true && \
  rm -rf /root/.cache/pip/* && \
  rm -rf ~/.wget-hsts && \
  \
  # Final Verify Phase
  echo "Final check of Aqua..." && \
  ls -la /root/.local/share/aquaproj-aqua/bin/terraform




#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#;;                                                                            ;;
#;;              ----==| G C P   D E V O P S   I M A G E |==----               ;;
#;;                                                                            ;;
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FROM base AS gcp-devops

LABEL name=gcp-devops

ARG TARGETARCH

SHELL ["/bin/bash", "-c"]
RUN \
  set -x && \
  # Install gcloud SDK via official APT repo
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin && \
  \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud version && \
  \
  # Cleanup
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true && \
  rm -rf /root/.cache/pip/* && \
  rm -rf ~/.wget-hsts

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
  python3 -m pip install --no-cache-dir --break-system-packages --upgrade boto3 cfn-lint requests && \
  \
  # AWS CLI Installation
  if [ "$TARGETARCH" = "amd64" ]; then \
  wget -qO /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip ; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
  wget -qO /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip ; \
  fi && \
  unzip -d /tmp /tmp/awscliv2.zip && \
  /tmp/aws/install && \
  \
  # AWS Session Manager Plugin Installation
  if [ "$TARGETARCH" = "amd64" ]; then \
  curl -fsSL https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb -o /tmp/session-manager-plugin.deb ; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
  curl -fsSL https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb -o /tmp/session-manager-plugin.deb ; \
  fi && \
  dpkg -i /tmp/session-manager-plugin.deb && \
  \
  aws --version && \
  # Cleanup
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/* && \
  rm -rf /var/tmp/* && \
  find / -regex ".*/__pycache__" -exec rm -rf '{}' \; || true && \
  rm -rf /root/.cache/pip/* && \
  rm -rf ~/.wget-hsts

ENTRYPOINT ["/bin/zsh"]
WORKDIR /work
