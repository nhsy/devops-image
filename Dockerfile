FROM ubuntu:24.04 AS base

LABEL name=base-devops

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV AQUA_ROOT_DIR=/root/.local/share/aquaproj-aqua
ENV PATH=/usr/lib/google-cloud-sdk/bin:$AQUA_ROOT_DIR/bin:$PATH
ENV TF_PLUGIN_CACHE_DIR=/opt/terraform/plugins-cache
ENV AQUA_GLOBAL_CONFIG=/etc/aqua/aqua.yaml

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --chmod=755 scripts/*.sh /usr/local/bin/

# Layer 1: APT packages (changes rarely)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
  set -x && \
  echo TARGETARCH: ${TARGETARCH} && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
  curl \
  git \
  gnupg \
  htop \
  jq \
  python3-pip \
  python3-venv \
  tree \
  unzip \
  vim \
  zip \
  zsh

# Layer 2: Node.js 20 via NodeSource (changes rarely)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
  apt-get install -y --no-install-recommends nodejs

# Layer 3: Python packages (changes occasionally)
RUN --mount=type=cache,target=/root/.cache/pip \
  python3 -m pip install --no-cache-dir --break-system-packages --upgrade pre-commit

# Layer 4: Aqua + tools (changes with aqua.yaml)
COPY aqua.yaml /etc/aqua/aqua.yaml
RUN curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v3.0.1/aqua-installer | bash -s -- -v v2.31.0 && \
  /root/.local/share/aquaproj-aqua/bin/aqua -c /etc/aqua/aqua.yaml i -a && \
  test -f /root/.local/share/aquaproj-aqua/bin/terraform || (echo "Terraform not found after install!" && ls -R /root/.local && exit 1)

# Layer 5: Customizations + unit tests
RUN useradd -m devops && \
  mkdir -p /opt/terraform/plugins-cache && \
  /usr/local/bin/setup-zshrc.sh && \
  /usr/local/bin/setup-bashrc.sh && \
  su - devops -c "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"" && \
  su - devops -c "/usr/local/bin/setup-zshrc.sh" && \
  PATH=/root/.local/share/aquaproj-aqua/bin:$PATH /usr/local/bin/verify-installation.sh && \
  /usr/local/bin/cleanup-build.sh

# Layer 6: AI CLI tools
RUN --mount=type=cache,target=/root/.npm \
  su - devops -c 'curl -fsSL https://claude.ai/install.sh | bash' && \
  npm install -g \
    @openai/codex@latest \
    @github/copilot@latest \
    @google/gemini-cli@latest \
    && \
  /usr/local/bin/cleanup-build.sh && \
  /home/devops/.local/bin/claude --version && \
  codex --version && \
  copilot --version && \
  gemini --version

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#;;                                                                            ;;
#;;              ----==| G C P   D E V O P S   I M A G E |==----               ;;
#;;                                                                            ;;
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FROM base AS gcp-devops

LABEL name=gcp-devops

ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
  set -x && \
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud version && \
  /usr/local/bin/cleanup-build.sh

USER devops
WORKDIR /home/devops
ENV PATH="/home/devops/bin:/home/devops/.local/bin:${PATH}"
ENTRYPOINT ["/bin/zsh"]

#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#;;                                                                            ;;
#;;              ----==| A W S   D E V O P S   I M A G E |==----               ;;
#;;                                                                            ;;
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FROM base AS aws-devops

LABEL name=aws-devops

ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/root/.cache/pip \
  set -x && \
  python3 -m pip install --no-cache-dir --break-system-packages --upgrade boto3 cfn-lint requests && \
  if [ "$TARGETARCH" = "amd64" ]; then \
  curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip ; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
  curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip -o /tmp/awscliv2.zip ; \
  fi && \
  unzip -d /tmp /tmp/awscliv2.zip && \
  /tmp/aws/install && \
  if [ "$TARGETARCH" = "amd64" ]; then \
  curl -fsSL https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb -o /tmp/session-manager-plugin.deb ; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
  curl -fsSL https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb -o /tmp/session-manager-plugin.deb ; \
  fi && \
  dpkg -i /tmp/session-manager-plugin.deb && \
  aws --version && \
  /usr/local/bin/cleanup-build.sh

USER devops
WORKDIR /home/devops
ENV PATH="/home/devops/bin:/home/devops/.local/bin:${PATH}"
ENTRYPOINT ["/bin/zsh"]
