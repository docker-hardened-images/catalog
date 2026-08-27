## How to use this image

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository** > **Mirror to
repository**, and then follow the on-screen instructions.

### Build and run a PyTorch application

The recommended way to use this image is to use a multi-stage Dockerfile with the `-dev` version of the image as the
build stage. For the runtime stage, simply remove the `-dev` suffix from the image tag. For example, use the image tag
`dhi.io/pytorch:2.9.0-cuda12.9-cudnn9-python3.12-debian13-dev` for the build stage, and use
`dhi.io/pytorch:2.9.0-cuda12.9-cudnn9-python3.12-debian13` for the runtime stage.

Create a new directory and use the following Dockerfile to get started. Replace `<tag>` with the image variant.

#### Simple Dockerfile

```dockerfile
FROM dhi.io/pytorch:<tag>

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/app/venv/bin:$PATH"

copy requirements.txt .
RUN ["pip", "install", "--no-cache-dir", "-r", "requirements.txt"]

WORKDIR /app
COPY train.py .

CMD ["python", "train.py"]
```

Because there is no shell in the default runtime, you must use the exec version of RUN and CMD, and use them with double
quotes.

Correct:

```
CMD ["python", "train.py"]
```

Incorrect:

```
CMD ['python", 'train.py']
CMD python train.py
```

Next, create `train.py` and `requirements.txt` files in the same directory.

### Example 1: Basic tensor operations and neural network training

This example demonstrates basic PyTorch functionality including tensor operations, automatic differentiation, and neural
network training.

```python
# train.py

import torch
import torch.nn as nn
import torch.optim as optim

class SimpleNet(nn.Module):
    """A simple neural network for demonstration."""
    def __init__(self):
        super(SimpleNet, self).__init__()
        self.fc1 = nn.Linear(10, 20)
        self.fc2 = nn.Linear(20, 10)
        self.fc3 = nn.Linear(10, 2)

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        x = self.fc3(x)
        return x

def main():
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"CUDA version: {torch.version.cuda}")
        print(f"GPU device: {torch.cuda.get_device_name(0)}")

    # Create model and move to GPU if available
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = SimpleNet().to(device)

    # Create synthetic training data
    X_train = torch.randn(100, 10).to(device)
    y_train = torch.randint(0, 2, (100,)).to(device)

    # Define loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)

    # Training loop
    model.train()
    for epoch in range(10):
        optimizer.zero_grad()
        outputs = model(X_train)
        loss = criterion(outputs, y_train)
        loss.backward()
        optimizer.step()

        if (epoch + 1) % 2 == 0:
            print(f"Epoch [{epoch+1}/10], Loss: {loss.item():.4f}")

    # Save model
    torch.save(model.state_dict(), "/workspace/model.pth")
    print("\nModel saved to /workspace/model.pth")
    print("Training completed successfully!")

if __name__ == "__main__":
    main()
```

Create a minimal `requirements.txt`:

```
numpy
```

Run the following commands to build and run the sample app:

```bash
docker build -t my-pytorch-app .
docker run --rm --name my-training-app my-pytorch-app
```

For GPU support, add the `--gpus all` flag:

```bash
docker run --rm --gpus all --name my-training-app my-pytorch-app
```

### Example 2: Image classification with TorchVision

This example demonstrates using PyTorch with TorchVision for computer vision tasks.

```python
# train.py

import torch
import torch.nn as nn
import torch.optim as optim
import torchvision
import torchvision.transforms as transforms
from torch.utils.data import DataLoader, TensorDataset

class ConvNet(nn.Module):
    """Simple convolutional neural network."""
    def __init__(self):
        super(ConvNet, self).__init__()
        self.conv1 = nn.Conv2d(3, 16, kernel_size=3, padding=1)
        self.conv2 = nn.Conv2d(16, 32, kernel_size=3, padding=1)
        self.pool = nn.MaxPool2d(2, 2)
        self.fc1 = nn.Linear(32 * 8 * 8, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = self.pool(torch.relu(self.conv1(x)))
        x = self.pool(torch.relu(self.conv2(x)))
        x = x.view(-1, 32 * 8 * 8)
        x = torch.relu(self.fc1(x))
        x = self.fc2(x)
        return x

def main():
    print(f"PyTorch version: {torch.__version__}")
    print(f"TorchVision version: {torchvision.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")

    # Set device
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")

    # Create synthetic image dataset
    transform = transforms.Compose([
        transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
    ])

    # Synthetic data (32x32 RGB images)
    images = torch.randn(100, 3, 32, 32)
    labels = torch.randint(0, 10, (100,))
    dataset = TensorDataset(images, labels)
    dataloader = DataLoader(dataset, batch_size=10, shuffle=True)

    # Create model
    model = ConvNet().to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.SGD(model.parameters(), lr=0.001, momentum=0.9)

    # Training loop
    print("\nStarting training...")
    model.train()
    for epoch in range(5):
        running_loss = 0.0
        for i, (inputs, labels_batch) in enumerate(dataloader):
            inputs = inputs.to(device)
            labels_batch = labels_batch.to(device)

            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels_batch)
            loss.backward()
            optimizer.step()

            running_loss += loss.item()

        print(f"Epoch {epoch+1}/5, Loss: {running_loss/len(dataloader):.4f}")

    # Save the trained model
    checkpoint = {
        'epoch': 5,
        'model_state_dict': model.state_dict(),
        'optimizer_state_dict': optimizer.state_dict(),
    }
    torch.save(checkpoint, '/workspace/checkpoint.pth')
    print("\nCheckpoint saved to /workspace/checkpoint.pth")
    print("Training completed successfully!")

if __name__ == "__main__":
    main()
```

Update `requirements.txt` to include additional packages if needed:

```
numpy
pillow
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your PyTorch models in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain PyTorch, Python, CUDA libraries, and cuDNN for GPU acceleration
  - Include a `/workspace` directory for model and data storage

- Build-time variants include `dev` in the variant name and are intended for use in the first stage of a multi-stage
  Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Include development tools like gcc, g++, and pip for installing additional packages
  - Are used to install dependencies and build custom PyTorch extensions

### CUDA and GPU support

Docker Hardened PyTorch images include CUDA and cuDNN libraries for GPU acceleration. The image tags indicate the CUDA
and cuDNN versions (e.g., `cuda12.9-cudnn9`). To use GPU acceleration:

1. Ensure your host has NVIDIA drivers installed
1. Install the NVIDIA Container Toolkit
1. Run containers with the `--gpus` flag

Example:

```bash
docker run --rm --gpus all dhi.io/pytorch:<tag> python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

### Multi-Stage Dockerfile

For multi-stage builds, use the `-dev` variant of the pytorch image for the build stage, and the regular runtime variant
for the runtime stage.

Note that you have shell access only in the `-dev` variant, so the runtime stage.

```dockerfile
# syntax=docker/dockerfile:1

## -----------------------------------------------------
## Build stage (use tag with -dev suffix)
FROM dhi.io/pytorch:<tag>-dev AS build-stage

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/app/venv/bin:$PATH"

# Create venv with access to system PyTorch installation
RUN python -m venv --system-site-packages /app/venv

# Install dependencies.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

## -----------------------------------------------------
## Final stage (use the same tag as above but without the -dev suffix)
FROM dhi.io/pytorch:<tag> AS runtime-stage

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/app/venv/bin:$PATH"

# Copy only the venv, as the runtime has all of the same system packages, including torch.
COPY --from=build-stage /app/venv /app/venv

# Copy the app code.
WORKDIR /app
COPY train.py .

CMD ["python", "train.py"]
```

### Python version

The image tags indicate the Python version included (e.g., `python3.12`). All PyTorch functionality is available through
the included Python interpreter.

## Migrate to a Docker Hardened Image

To migrate your PyTorch application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must
update the base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are
listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                              |
| :----------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened PyTorch image.                                                                                           |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                  |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                            |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                          |
| CUDA libraries     | CUDA and cuDNN libraries are pre-installed. No need to install them separately.                                                                                             |
| Workspace          | Use the `/workspace` directory for storing models, checkpoints, and data. This directory is writable by the nonroot user.                                                   |
| Entry point        | Docker Hardened PyTorch images use `python3` as the default command. Update your Dockerfile if you need a different entry point.                                            |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   Pay attention to the CUDA, cuDNN, and Python versions in the tag.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   PyTorch applications, this is typically going to be an image tagged as `dev` because it has the tools needed to
   install packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Debian-based images, you can use `apt-get` to install system packages, and `pip` to install Python packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. The `/workspace` directory is pre-configured to be writable by the nonroot user for
storing models and data.

### GPU access

If GPU acceleration is not working:

1. Verify NVIDIA drivers are installed on the host: `nvidia-smi`
1. Verify NVIDIA Container Toolkit is installed
1. Use the `--gpus` flag when running containers
1. Check CUDA availability inside the container: `python -c "import torch; print(torch.cuda.is_available())"`

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened PyTorch images use `python3` as the default command. Use `docker inspect` to inspect entry points and
update your Dockerfile if necessary.
