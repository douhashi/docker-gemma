FROM runpod/worker-vllm:stable-cuda12.1.0

ENV HF_HOME="/models"

RUN pip install huggingface_hub && \
    huggingface-cli download cyankiwi/gemma-4-26B-A4B-it-AWQ-4bit \
      --local-dir /models/gemma-4-26B-A4B-it-AWQ-4bit \
      --local-dir-use-symlinks False

ENV MODEL_NAME="/models/gemma-4-26B-A4B-it-AWQ-4bit"
ENV QUANTIZATION="awq"
ENV MAX_MODEL_LENGTH=8192
ENV GPU_MEMORY_UTILIZATION=0.90
ENV DTYPE="float16"
