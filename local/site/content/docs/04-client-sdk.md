---
title: "containerd Client SDK"
weight: 50
---

# containerd Client SDK

## Overview

The containerd client SDK provides a Go library for interacting with the containerd daemon. It offers high-level abstractions for container management, image operations, and task execution.

**Location**: `client/`  
**Package**: `github.com/containerd/containerd/v2/client`

## Client Architecture


{{< figure src="/images/diagrams/diagram-0eeda8285e9c.svg" alt="Diagram" class="diagram" >}}


## Client Initialization

### Creating a Client

```go
import (
    "github.com/containerd/containerd/v2/client"
)

func main() {
    // Connect to default socket
    client, err := client.New("/run/containerd/containerd.sock")
    if err != nil {
        panic(err)
    }
    defer client.Close()
    
    // Use client...
}
```

### Client Options

```go
// With custom namespace
client, err := client.New(address,
    client.WithDefaultNamespace("custom"),
)

// With custom runtime
client, err := client.New(address,
    client.WithDefaultRuntime("io.containerd.runc.v2"),
)

// With custom platform
client, err := client.New(address,
    client.WithDefaultPlatform(platforms.Default()),
)

// With timeout
client, err := client.New(address,
    client.WithTimeout(30*time.Second),
)

// With dial options
client, err := client.New(address,
    client.WithDialOpts([]grpc.DialOption{...}),
)
```

### Client Structure

```go
type Client struct {
    defaultns string
    platform  platforms.MatchComparer
    defaults  struct {
        runtime   string
        sandboxer string
    }
    services  services
    // ...
}
```

## Container Operations

### Container Interface

```go
type Container interface {
    ID() string
    Info(context.Context, ...InfoOpts) (containers.Container, error)
    Delete(context.Context, ...DeleteOpts) error
    NewTask(context.Context, cio.Creator, ...NewTaskOpts) (Task, error)
    Spec(context.Context) (*oci.Spec, error)
    Task(context.Context, cio.Attach) (Task, error)
    Image(context.Context) (Image, error)
    Labels(context.Context) (map[string]string, error)
    SetLabels(context.Context, map[string]string) (map[string]string, error)
    Extensions(context.Context) (map[string]typeurl.Any, error)
    Update(context.Context, ...UpdateContainerOpts) error
    Checkpoint(context.Context, string, ...CheckpointOpts) (Image, error)
}
```

### Creating a Container

```go
// Pull image first
image, err := client.Pull(ctx, "docker.io/library/redis:alpine",
    containerd.WithPullUnpack,
)

// Create container
container, err := client.NewContainer(ctx, "redis-server",
    containerd.WithImage(image),
    containerd.WithNewSnapshot("redis-rootfs", image),
    containerd.WithNewSpec(oci.WithImageConfig(image)),
)
```

### Container Options

```go
// WithImage sets the image for container
containerd.WithImage(image)

// WithSnapshot uses existing snapshot
containerd.WithSnapshot("snapshot-key")

// WithNewSnapshot creates new snapshot
containerd.WithNewSnapshot("snapshot-key", image)

// WithNewSpec creates OCI spec
containerd.WithNewSpec(specOpts...)

// WithSpec uses existing spec
containerd.WithSpec(spec)

// WithContainerLabels sets labels
containerd.WithContainerLabels(map[string]string{
    "app": "redis",
})

// WithRuntime specifies runtime
containerd.WithRuntime("io.containerd.runc.v2", nil)

// WithSandbox associates with sandbox
containerd.WithSandbox("sandbox-id")
```

### OCI Spec Options

```go
import "github.com/containerd/containerd/v2/pkg/oci"

// Basic spec options
oci.WithImageConfig(image)           // Use image config
oci.WithProcessArgs("redis-server")  // Set process args
oci.WithEnv([]string{"KEY=value"})   // Set environment
oci.WithHostname("redis")            // Set hostname
oci.WithMounts([]specs.Mount{...})   // Add mounts

// Resource limits
oci.WithMemoryLimit(512 * 1024 * 1024)  // 512MB
oci.WithCPUCFS(50000, 100000)            // CPU quota

// Capabilities
oci.WithCapabilities([]string{
    "CAP_NET_BIND_SERVICE",
})

// User
oci.WithUser("1000:1000")
oci.WithUserNamespace(...)

// Rootfs
oci.WithRootFSPath("/path/to/rootfs")
oci.WithRootFSReadonly()

// Namespaces
oci.WithLinuxNamespace(specs.NetworkNamespace, "/var/run/netns/test")

// Devices
oci.WithDevices("/dev/null", "rwm")
```

### Listing Containers

```go
containers, err := client.Containers(ctx)
for _, container := range containers {
    fmt.Printf("Container: %s\n", container.ID())
}

// With filters
containers, err := client.Containers(ctx, 
    "labels.app==redis",
    "labels.env==production",
)
```

### Getting Container Info

```go
container, err := client.LoadContainer(ctx, "redis-server")

info, err := container.Info(ctx)
fmt.Printf("ID: %s\n", info.ID)
fmt.Printf("Image: %s\n", info.Image)
fmt.Printf("Runtime: %s\n", info.Runtime.Name)
fmt.Printf("Snapshotter: %s\n", info.Snapshotter)
fmt.Printf("SnapshotKey: %s\n", info.SnapshotKey)
```

### Updating Container

```go
err := container.Update(ctx,
    containerd.UpdateContainerOpts(func(ctx context.Context, client *containerd.Client, c *containers.Container) error {
        c.Labels["updated"] = "true"
        return nil
    }),
)
```

### Deleting Container

```go
// Delete container metadata
err := container.Delete(ctx)

// Delete with snapshot cleanup
err := container.Delete(ctx, containerd.WithSnapshotCleanup)
```

## Task Operations

### Task Interface

```go
type Task interface {
    ID() string
    PID() uint32
    Start(context.Context) error
    Kill(context.Context, syscall.Signal, ...KillOpts) error
    Wait(context.Context) (<-chan ExitStatus, error)
    CloseIO(context.Context, ...IOCloserOpts) error
    Resize(context.Context, uint32, uint32) error
    IO() cio.IO
    Status(context.Context) (Status, error)
    Pause(context.Context) error
    Resume(context.Context) error
    Exec(context.Context, string, *specs.Process, cio.Creator) (Process, error)
    Pids(context.Context) ([]ProcessInfo, error)
    Checkpoint(context.Context, ...CheckpointTaskOpts) (Image, error)
    Update(context.Context, ...UpdateTaskOpts) error
    LoadProcess(context.Context, string, cio.Attach) (Process, error)
    Metrics(context.Context) (*types.Metric, error)
    Delete(context.Context, ...ProcessDeleteOpts) (*ExitStatus, error)
}
```

### Creating and Starting a Task

```go
// Create task
task, err := container.NewTask(ctx, cio.NewCreator(cio.WithStdio))
if err != nil {
    return err
}
defer task.Delete(ctx)

// Start task
err = task.Start(ctx)
if err != nil {
    return err
}

// Wait for task
statusC, err := task.Wait(ctx)

// Task is now running
fmt.Printf("Task PID: %d\n", task.PID())

// Wait for exit
status := <-statusC
code, _, err := status.Result()
fmt.Printf("Exit code: %d\n", code)
```

### Task I/O Options

```go
// Standard I/O
task, err := container.NewTask(ctx, cio.NewCreator(cio.WithStdio))

// Custom I/O
task, err := container.NewTask(ctx, cio.NewCreator(
    cio.WithStreams(stdin, stdout, stderr),
))

// Terminal mode
task, err := container.NewTask(ctx, cio.NewCreator(
    cio.WithTerminal,
))

// Log to file
task, err := container.NewTask(ctx, cio.NewCreator(
    cio.WithFIFODir("/var/log/containerd"),
))

// Null I/O
task, err := container.NewTask(ctx, cio.NullIO)
```

### Task Status

```go
status, err := task.Status(ctx)
fmt.Printf("Status: %s\n", status.Status)  // running, created, stopped, paused
fmt.Printf("Exit Status: %d\n", status.ExitStatus)
fmt.Printf("Exit Time: %s\n", status.ExitTime)
```

### Killing a Task

```go
// Send SIGTERM
err := task.Kill(ctx, syscall.SIGTERM)

// Send SIGKILL
err := task.Kill(ctx, syscall.SIGKILL)

// Kill all processes in task
err := task.Kill(ctx, syscall.SIGKILL, containerd.WithKillAll)
```

### Pausing and Resuming

```go
// Pause task
err := task.Pause(ctx)

// Resume task
err := task.Resume(ctx)
```

### Executing Additional Processes

```go
// Create process spec
processSpec := &specs.Process{
    Args: []string{"/bin/sh"},
    Cwd:  "/",
    Terminal: true,
}

// Execute process
process, err := task.Exec(ctx, "sh-1", processSpec, cio.NewCreator(cio.WithStdio))
if err != nil {
    return err
}

// Start process
err = process.Start(ctx)

// Wait for process
statusC, err := process.Wait(ctx)
status := <-statusC
```

### Task Metrics

```go
metrics, err := task.Metrics(ctx)
// Metrics contain CPU, memory, I/O statistics
```

### Task Checkpoint

```go
// Create checkpoint
checkpoint, err := task.Checkpoint(ctx,
    containerd.WithCheckpointName("checkpoint-1"),
)

// Checkpoint image can be used to restore
```

## Image Operations

### Image Interface

```go
type Image interface {
    Name() string
    Target() ocispec.Descriptor
    Labels() map[string]string
    Unpack(context.Context, string, ...UnpackOpt) error
    RootFS(ctx context.Context) ([]digest.Digest, error)
    Size(ctx context.Context) (int64, error)
    Usage(context.Context, ...UsageOpt) (int64, error)
    Config(ctx context.Context) (ocispec.Descriptor, error)
    IsUnpacked(context.Context, string) (bool, error)
    ContentStore() content.Store
    Metadata() images.Image
    Platform() platforms.MatchComparer
    Spec(ctx context.Context) (ocispec.Image, error)
}
```

### Pulling Images

```go
// Pull image
image, err := client.Pull(ctx, "docker.io/library/redis:alpine")

// Pull with unpack
image, err := client.Pull(ctx, "docker.io/library/redis:alpine",
    containerd.WithPullUnpack,
)

// Pull with snapshotter
image, err := client.Pull(ctx, "docker.io/library/redis:alpine",
    containerd.WithPullUnpack,
    containerd.WithPullSnapshotter("overlayfs"),
)

// Pull with platform
image, err := client.Pull(ctx, "docker.io/library/redis:alpine",
    containerd.WithPlatform("linux/amd64"),
)

// Pull with resolver (custom registry auth)
image, err := client.Pull(ctx, "docker.io/library/redis:alpine",
    containerd.WithResolver(resolver),
)
```

### Pushing Images

```go
err := client.Push(ctx, "docker.io/myorg/myimage:latest", image.Target())

// With resolver
err := client.Push(ctx, "docker.io/myorg/myimage:latest", image.Target(),
    containerd.WithResolver(resolver),
)
```

### Listing Images

```go
images, err := client.ImageService().List(ctx)
for _, img := range images {
    fmt.Printf("Image: %s\n", img.Name)
    fmt.Printf("Target: %s\n", img.Target.Digest)
}

// With filters
images, err := client.ImageService().List(ctx, "name~=redis")
```

### Getting Image Info

```go
image, err := client.GetImage(ctx, "docker.io/library/redis:alpine")

// Image name
name := image.Name()

// Image target (manifest descriptor)
target := image.Target()

// Image size
size, err := image.Size(ctx)

// Image config
config, err := image.Config(ctx)

// Image spec (OCI image spec)
spec, err := image.Spec(ctx)

// RootFS layers
diffIDs, err := image.RootFS(ctx)
```

### Unpacking Images

```go
// Unpack image layers to snapshotter
err := image.Unpack(ctx, "overlayfs")

// Check if unpacked
unpacked, err := image.IsUnpacked(ctx, "overlayfs")
```

### Deleting Images

```go
err := client.ImageService().Delete(ctx, image.Name())

// Synchronous delete (wait for GC)
err := client.ImageService().Delete(ctx, image.Name(),
    images.SynchronousDelete(),
)
```

### Importing/Exporting Images

```go
// Export image to tar
err := client.Export(ctx, w, archive.WithImage(imageStore, image.Name()))

// Import image from tar
images, err := client.Import(ctx, r)
```

## Content Store Operations

### Accessing Content Store

```go
contentStore := client.ContentStore()
```

### Writing Content

```go
// Start writing
writer, err := contentStore.Writer(ctx,
    content.WithRef("layer-download"),
    content.WithDescriptor(desc),
)
defer writer.Close()

// Write data
_, err = io.Copy(writer, reader)

// Commit
err = writer.Commit(ctx, desc.Size, desc.Digest)
```

### Reading Content

```go
readerAt, err := contentStore.ReaderAt(ctx, desc)
defer readerAt.Close()

// Read content
buf := make([]byte, desc.Size)
_, err = readerAt.ReadAt(buf, 0)
```

### Content Info

```go
info, err := contentStore.Info(ctx, desc.Digest)
fmt.Printf("Digest: %s\n", info.Digest)
fmt.Printf("Size: %d\n", info.Size)
fmt.Printf("Labels: %v\n", info.Labels)
```

## Snapshot Operations

### Accessing Snapshotter

```go
snapshotter := client.SnapshotService("overlayfs")
```

### Creating Snapshots

```go
// Prepare writable snapshot
mounts, err := snapshotter.Prepare(ctx, "container-rootfs", "parent-snapshot")

// View read-only snapshot
mounts, err := snapshotter.View(ctx, "view-key", "parent-snapshot")

// Commit snapshot
err = snapshotter.Commit(ctx, "committed-snapshot", "active-snapshot")
```

### Mounting Snapshots

```go
mounts, err := snapshotter.Mounts(ctx, "snapshot-key")

// Mount to target
err = mount.All(mounts, "/mnt/target")
defer mount.Unmount("/mnt/target", 0)
```

### Snapshot Info

```go
info, err := snapshotter.Stat(ctx, "snapshot-key")
fmt.Printf("Name: %s\n", info.Name)
fmt.Printf("Parent: %s\n", info.Parent)
fmt.Printf("Kind: %s\n", info.Kind)  // Active, Committed, View
```

### Snapshot Usage

```go
usage, err := snapshotter.Usage(ctx, "snapshot-key")
fmt.Printf("Size: %d bytes\n", usage.Size)
fmt.Printf("Inodes: %d\n", usage.Inodes)
```

## Namespace Operations

### Setting Namespace

```go
ctx := namespaces.WithNamespace(ctx, "custom-namespace")
```

### Creating Namespace

```go
namespaceStore := client.NamespaceService()
err := namespaceStore.Create(ctx, "custom-namespace", nil)
```

### Listing Namespaces

```go
namespaces, err := namespaceStore.List(ctx)
for _, ns := range namespaces {
    fmt.Printf("Namespace: %s\n", ns)
}
```

### Deleting Namespace

```go
err := namespaceStore.Delete(ctx, "custom-namespace")
```

## Lease Operations

### Creating Lease

```go
leaseManager := client.LeasesService()

lease, err := leaseManager.Create(ctx)

// With ID
lease, err := leaseManager.Create(ctx, leases.WithID("my-lease"))

// With expiration
lease, err := leaseManager.Create(ctx, leases.WithExpiration(1*time.Hour))

// With labels
lease, err := leaseManager.Create(ctx, leases.WithLabels(map[string]string{
    "app": "myapp",
}))
```

### Adding Resources to Lease

```go
err := leaseManager.AddResource(ctx, lease, leases.Resource{
    ID:   "snapshot-key",
    Type: "snapshots/overlayfs",
})

err := leaseManager.AddResource(ctx, lease, leases.Resource{
    ID:   digest.String(),
    Type: "content",
})
```

### Deleting Lease

```go
err := leaseManager.Delete(ctx, lease)

// Synchronous delete (trigger GC)
err := leaseManager.Delete(ctx, lease, leases.SynchronousDelete)
```

## Event Streaming

### Subscribing to Events

```go
eventService := client.EventService()

// Subscribe to all events
eventCh, errCh := eventService.Subscribe(ctx)

// Subscribe with filters
eventCh, errCh := eventService.Subscribe(ctx,
    "topic~=/containers/.*",
    "topic~=/tasks/.*",
)

// Process events
for {
    select {
    case event := <-eventCh:
        fmt.Printf("Event: %s\n", event.Topic)
        fmt.Printf("Namespace: %s\n", event.Namespace)
        // Unmarshal event data
        
    case err := <-errCh:
        fmt.Printf("Error: %v\n", err)
        return
    }
}
```

### Event Types

**Container Events**:
- `/containers/create`
- `/containers/update`
- `/containers/delete`

**Task Events**:
- `/tasks/create`
- `/tasks/start`
- `/tasks/exit`
- `/tasks/delete`
- `/tasks/paused`
- `/tasks/resumed`
- `/tasks/checkpointed`

**Image Events**:
- `/images/create`
- `/images/update`
- `/images/delete`

## Complete Example

### Running a Container

```go
package main

import (
    "context"
    "fmt"
    "syscall"
    
    "github.com/containerd/containerd/v2/client"
    "github.com/containerd/containerd/v2/pkg/cio"
    "github.com/containerd/containerd/v2/pkg/namespaces"
    "github.com/containerd/containerd/v2/pkg/oci"
)

func main() {
    // Create client
    client, err := client.New("/run/containerd/containerd.sock")
    if err != nil {
        panic(err)
    }
    defer client.Close()
    
    // Set namespace
    ctx := namespaces.WithNamespace(context.Background(), "default")
    
    // Pull image
    image, err := client.Pull(ctx, "docker.io/library/redis:alpine",
        client.WithPullUnpack,
    )
    if err != nil {
        panic(err)
    }
    
    // Create container
    container, err := client.NewContainer(ctx, "redis-server",
        client.WithImage(image),
        client.WithNewSnapshot("redis-rootfs", image),
        client.WithNewSpec(oci.WithImageConfig(image)),
    )
    if err != nil {
        panic(err)
    }
    defer container.Delete(ctx, client.WithSnapshotCleanup)
    
    // Create task
    task, err := container.NewTask(ctx, cio.NewCreator(cio.WithStdio))
    if err != nil {
        panic(err)
    }
    defer task.Delete(ctx)
    
    // Wait for task
    exitStatusC, err := task.Wait(ctx)
    if err != nil {
        panic(err)
    }
    
    // Start task
    if err := task.Start(ctx); err != nil {
        panic(err)
    }
    
    fmt.Printf("Container started with PID: %d\n", task.PID())
    
    // Wait for exit or kill after timeout
    // ... (implement your logic)
    
    // Kill task
    if err := task.Kill(ctx, syscall.SIGTERM); err != nil {
        panic(err)
    }
    
    // Wait for exit
    status := <-exitStatusC
    code, _, err := status.Result()
    fmt.Printf("Container exited with code: %d\n", code)
}
```

## Best Practices

### 1. Context Management

```go
// Use context with timeout
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()

// Use namespace context
ctx = namespaces.WithNamespace(ctx, "production")
```

### 2. Resource Cleanup

```go
// Always defer cleanup
container, err := client.NewContainer(ctx, id, opts...)
if err != nil {
    return err
}
defer container.Delete(ctx, client.WithSnapshotCleanup)

task, err := container.NewTask(ctx, ioCreator)
if err != nil {
    return err
}
defer task.Delete(ctx)
```

### 3. Error Handling

```go
if err != nil {
    if errdefs.IsNotFound(err) {
        // Handle not found
    } else if errdefs.IsAlreadyExists(err) {
        // Handle already exists
    } else {
        // Handle other errors
    }
}
```

### 4. Lease Management

```go
// Use leases for temporary resources
ctx, done, err := client.WithLease(ctx)
if err != nil {
    return err
}
defer done(ctx)

// Resources created in this context are protected
```

## Summary

The containerd client SDK provides:

1. **High-level API**: Easy-to-use container operations
2. **Comprehensive**: Full access to all containerd features
3. **Type-safe**: Strong typing for all operations
4. **Flexible**: Extensive options for customization
5. **Efficient**: Direct gRPC communication
6. **Well-documented**: Godoc documentation available

Key features:
- Container lifecycle management
- Image pull/push/management
- Task execution and monitoring
- Content and snapshot operations
- Event streaming
- Namespace isolation
- Lease management
