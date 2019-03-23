# nvidia/cuda
# https://hub.docker.com/r/nvidia/cuda
FROM nvidia/cuda:10.0-cudnn7-runtime-ubuntu18.04 

LABEL maintainer="Timothy Liu <timothyl@nvidia.com>"

USER root

ENV DEBIAN_FRONTEND noninteractive

# Install all OS dependencies

RUN apt-get update && \
    apt-get install -yq --no-install-recommends --no-upgrade \
    apt-utils && \
    apt-get install -yq --no-install-recommends --no-upgrade \
    curl \
    wget \
    bzip2 \
    ca-certificates \
    locales \
    fonts-liberation \
    build-essential \
    inkscape \
    jed \
    libsm6 \
    libxext-dev \
    libxrender1 \
    lmodern \
    netcat \
    pandoc \
    #texlive-fonts-extra \
    texlive-fonts-recommended \
    texlive-generic-recommended \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-xetex \
    ffmpeg \
    graphviz\
    git \
    nano \
    htop \
    zip \
    unzip \
    libncurses5-dev \
    libncursesw5-dev \
    libopenmpi-dev \
    libopenblas-base \
    libopenblas-dev \
    libomp-dev \
    libjpeg-dev \
    libpng-dev \
    openssh-client \
    openssh-server \
    mecab \
    mecab-ipadic-utf8 \
    libmecab-dev \
    swig \
    pkg-config \
    g++ \
    zlib1g-dev \
    protobuf-compiler && \
    wget \
     https://developer.nvidia.com/compute/machine-learning/tensorrt/5.0/GA_5.0.2.6/local_repos/nv-tensorrt-repo-ubuntu1804-cuda10.0-trt5.0.2.6-ga-20181009_1-1_amd64.deb && \
    dpkg -i *.deb && \
    apt-get update && \
    apt-get install tensorrt -yq && \
    apt-get install --no-upgrade -yq \
    libnvinfer5 \
    libnvinfer-dev \
    python3-libnvinfer-dev \
    python3-libnvinfer \
    uff-converter-tf && \
    apt-get clean && \
    rm *.deb && \
    rm -rf /var/lib/apt/lists/*

# Configure environment

ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

# script used to restore permissions after each step as root

ADD fix-permissions /usr/local/bin/fix-permissions

# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \  
    groupadd wheel -g 11 && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd && \
    fix-permissions $HOME && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /opt

USER $NB_UID

RUN fix-permissions /home/$NB_USER

# Install conda as jovyan

ENV MINICONDA_VERSION 4.5.12

RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda install --quiet --yes conda="${MINICONDA_VERSION%.*}.*" && \
    $CONDA_DIR/bin/conda update --all --quiet --yes && \
    conda install -n root conda-build && \
    conda install -c nvidia -c numba -c pytorch -c conda-forge -c rapidsai -c defaults  --quiet --yes \
    'cudatoolkit=10.0' \
    'tk' \
    'pytest' \
    'numpy>=1.16.1' \
    'numba>=0.41.0dev' \
    'pandas' \
    'blas=*=openblas' \
    'cython>=0.29' && \
    conda install -c pytorch pytorch torchvision cudatoolkit=10.0 --quiet --yes && \
    conda install -c anaconda tensorflow-gpu=1.13 --quiet --yes && \
    pip install --ignore-installed --no-cache-dir 'pyyaml>=4.2b4' && \
    cd /home/$NB_USER && \
    wget https://raw.githubusercontent.com/NVAITC/ai-lab/master/requirements.txt && \
    pip install --no-cache-dir -r /home/$NB_USER/requirements.txt && \
    pip uninstall pillow -y && \
    CC="cc -mavx2" pip install -U --force-reinstall --no-cache-dir pillow-simd && \
    rm /home/$NB_USER/requirements.txt && \
    conda install -c pytorch -c fastai fastai dataclasses && \
    pip install --ignore-installed --no-cache-dir 'msgpack>=0.6.0' && \
    conda clean -tipsy && \
    conda build purge-all && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# if you don't run this you could get:
# BlockingIOError(11, 'write could not complete without blocking', 69632)
RUN python -c 'import os,sys,fcntl; flags = fcntl.fcntl(sys.stdout, fcntl.F_GETFL); fcntl.fcntl(sys.stdout, fcntl.F_SETFL, flags&~os.O_NONBLOCK);'

# Install Jupyter Notebook, Lab, and Hub

RUN conda install -c conda-forge --quiet --yes \
    'notebook=5.7.*' \
    'jupyterhub=0.9.*' \
    'jupyterlab=0.35.*' \
    'jupyter_contrib_nbextensions' \
    'ipywidgets=7.2*' && \
    jupyter notebook --generate-config && \
    # Activate ipywidgets extension in the environment that runs the notebook server
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    jupyter contrib nbextension install --sys-prefix && \
    # Also activate ipywidgets extension for JupyterLab
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter labextension install jupyterlab_bokeh && \
    jupyter labextension install @jupyterlab/hub-extension && \
    pip install --no-cache-dir jupyterlab_github jupyter-tensorboard nbdime && \
    jupyter tensorboard enable --sys-prefix && \
    nbdime extensions --enable --sys-prefix && \
    jupyter serverextension enable --sys-prefix jupyterlab_github && \
    jupyter labextension install @jupyterlab/github && \
    jupyter labextension install nbdime-jupyterlab && \
    conda install --quiet --yes 'tini=0.18.0' && \
    conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    conda clean -tipsy && \
    conda build purge-all && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# extras

# build TF from source

ENV PYTHON_BIN_PATH=/opt/conda/bin/python3
ENV PYTHON_LIB_PATH=/opt/conda/lib/python3.6/site-packages
ENV CUDA_TOOLKIT_PATH=/usr/local/cuda
ENV CUDNN_INSTALL_PATH=/usr/local/cuda
ENV TF_NEED_GCP=0
ENV TF_NEED_CUDA=1
ENV TF_CUDA_VERSION=10.0
ENV TF_CUDA_COMPUTE_CAPABILITIES=7.0,6.1,6.0,3.7
ENV TF_NEED_HDFS=0
ENV TF_NEED_OPENCL=0
ENV TF_NEED_JEMALLOC=1
ENV TF_ENABLE_XLA=1
ENV TF_NEED_VERBS=0
ENV TF_CUDA_CLANG=0
ENV TF_CUDNN_VERSION=7.4
ENV TF_NEED_MKL=0
ENV TF_DOWNLOAD_MKL=0
ENV TF_NEED_AWS=0
ENV TF_NEED_MPI=0
ENV TF_NEED_GDR=0
ENV TF_NEED_S3=0
ENV TF_NEED_OPENCL_SYCL=0
ENV TF_SET_ANDROID_WORKSPACE=0
ENV TF_NEED_COMPUTECPP=0
ENV TF_NEED_ROCM=0
ENV TF_NEED_KAFKA=0
ENV TF_NEED_TENSORRT=0
ENV TF_NCCL_VERSION=2.4
ENV GCC_HOST_COMPILER_PATH=/usr/bin/gcc
ENV CC_OPT_FLAGS="-march=broadwell"

USER $NB_UID

RUN cd /home/$NB_USER/ && \
    wget https://github.com/bazelbuild/bazel/releases/download/0.19.2/bazel-0.19.2-installer-linux-x86_64.sh && \
    chmod +x bazel-0.19.2-installer-linux-x86_64.sh && \
    ./bazel-0.19.2-installer-linux-x86_64.sh && \
    rm bazel-0.19.2-installer-linux-x86_64.sh && \
    bazel && \
    git clone https://github.com/tensorflow/tensorflow.git && \
    cd tensorflow && \
    bazel clean && \
    git checkout r1.13 && \
    ./configure && \
    bazel build \
        --config=opt \
        --config=cuda \
        //tensorflow/tools/pip_package:build_pip_package && \
    ./bazel-bin/tensorflow/tools/pip_package/build_pip_package \
        /home/$NB_USER/ && \
    bazel clean && \
    cd .. && \
    pip install --no-cache-dir *.whl && \
    rm -rf /home/$NB_USER/tensorflow *.whl && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions /home/$NB_USER

# OpenMPI + Horovod

RUN mkdir /tmp/openmpi && \
    cd /tmp/openmpi && \
    wget https://www.open-mpi.org/software/ompi/v3.1/downloads/openmpi-3.1.2.tar.gz && \
    tar zxf openmpi-3.1.2.tar.gz && \
    cd openmpi-3.1.2 && \
    ./configure --enable-orterun-prefix-by-default && \
    make -j $(nproc) all && \
    make install && \
    ldconfig && \
    rm -rf /tmp/openmpi

RUN ldconfig /usr/local/cuda/targets/x86_64-linux/lib/stubs

USER $NB_UID

RUN HOROVOD_GPU_ALLREDUCE=NCCL HOROVOD_WITH_TENSORFLOW=1 HOROVOD_WITH_PYTORCH=1 \
    pip install --no-cache-dir horovod && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions /home/$NB_USER

USER root

RUN ldconfig && \
    mv /usr/local/bin/mpirun /usr/local/bin/mpirun.real && \
    echo '#!/bin/bash' > /usr/local/bin/mpirun && \
    echo 'mpirun.real --allow-run-as-root "$@"' >> /usr/local/bin/mpirun && \
    chmod a+x /usr/local/bin/mpirun && \
    echo "hwloc_base_binding_policy = none" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "rmaps_base_mapping_policy = slot" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "btl_tcp_if_exclude = lo,docker0" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo NCCL_DEBUG=INFO >> /etc/nccl.conf && \
    mkdir -p /var/run/sshd && \
    cat /etc/ssh/ssh_config | grep -v StrictHostKeyChecking > /etc/ssh/ssh_config.new && \
    echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config.new && \
    mv /etc/ssh/ssh_config.new /etc/ssh/ssh_config

# nvtop

RUN cd /home/$NB_USER && \
    git clone https://github.com/Syllo/nvtop.git && \
    mkdir -p nvtop/build && cd nvtop/build && \
    cmake .. && \
    make && make install && \
    cd .. && rm -rf nvtop && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions /home/$NB_USER

USER $NB_UID

# RAPIDS

RUN pip install --no-cache-dir \
    cudf-cuda100 \
    cuml-cuda100 \
    cugraph-cuda100 \
    nvstrings-cuda100 \
    dask-cuml \
    xgboost && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions /home/$NB_USER

# autokeras

RUN cd /home/$NB_USER && \
    git clone https://github.com/NVAITC/autokeras.git && \
    cd autokeras/ && python setup.py install && \
    cd .. && rm -rf autokeras && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions /home/$NB_USER

# flair

RUN cd /home/$NB_USER && \
    git clone https://github.com/NVAITC/flair.git && \
    cd flair/ && python setup.py install && \
    cd .. && rm -rf flair && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions /home/$NB_USER

# Import matplotlib the first time to build the font cache

USER root

ENV XDG_CACHE_HOME /home/$NB_USER/.cache/

RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions /home/$NB_USER

# end extras

EXPOSE 8888
EXPOSE 6006

WORKDIR $HOME

# Configure container startup

ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Add local files as late as possible to avoid cache busting

COPY start.sh /usr/local/bin/
COPY start-notebook.sh /usr/local/bin/
COPY start-singleuser.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/

RUN fix-permissions /etc/jupyter/ && \
    usermod -s /bin/bash $NB_USER

# Switch back to jovyan to avoid accidental container runs as root

USER $NB_UID
