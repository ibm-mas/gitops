# Locking Mechanisms

When using the MAS CLI GitOps functions to push configuration changes to your Git repository, a locking mechanism is employed to prevent concurrent updates from causing merge conflicts. This ensures that multiple processes or users can safely interact with the same configuration repository without corrupting the state.

## Overview

The GitOps CLI functions support two locking mechanisms to coordinate concurrent access to the configuration repository:

1. **Git Branch Locking (Default)** - Uses temporary Git branches to coordinate access
2. **Redis-Based Locking (Optional)** - Uses Redis for distributed locking with better performance

Both approaches ensure sequential execution of updates when multiple processes attempt to modify the same configuration files simultaneously.

## Git Branch Locking (Default)

### How It Works

The Git branch locking mechanism creates temporary lock branches in your Git repository to coordinate access between concurrent processes. When a GitOps CLI function needs to push changes:

1. **Lock Acquisition**: The process attempts to create a uniquely named lock branch (e.g., `lock.gitops.account.cluster.instance`)
2. **Conflict Detection**: If the lock branch already exists, another process is currently making changes
3. **Retry Logic**: The process waits and retries until it successfully acquires the lock
4. **Change Application**: Once the lock is acquired, the process applies its changes
5. **Lock Release**: After pushing changes, the lock branch is automatically deleted

### Lock Branch Naming

Lock branches follow a consistent naming pattern based on the scope of the operation:

```
lock.<operation>.<account>.<cluster>[.<instance>]
```

For example:  
- `lock.gitops-cluster.dev.masdemo1`  
- `lock.gitops-suite.dev.masdemo1.inst1`

This naming scheme ensures that operations affecting different scopes can proceed in parallel, while operations affecting the same scope are serialized.

### Advantages

- **No external dependencies**: Uses only Git, which is already required for GitOps
- **Simple setup**: No additional infrastructure needed
- **Transparent**: Lock branches are visible in the repository
- **Automatic cleanup**: Exit traps ensure locks are released even on failure
- **Scope-based**: Different operations can run in parallel if they affect different scopes

### Limitations

- **Polling-based**: Processes must poll to check if the lock is available
- **Network dependent**: Requires network access to the Git repository
- **Cleanup required**: If a process crashes without cleanup, manual intervention may be needed
- **Not suitable for high-frequency updates**: The retry delay makes this approach less suitable for very frequent concurrent updates

## Troubleshooting

### Stuck Lock Branches

If a lock branch is not properly cleaned up (e.g., due to a process crash), subsequent operations may wait indefinitely. You can identify and resolve this issue:

1. **List lock branches**:  
   ```
   git branch -r | grep "lock\."
   ```

2. **Delete stuck lock branch**:  
   ```
   git push origin --delete lock.gitops.account.cluster.instance
   ```

Lock branches follow the naming pattern `lock.*` and should only exist temporarily during active operations.

### Local Repository Conflicts

If a process exits early, it may leave a local repository clone that blocks subsequent operations:

```
fatal: destination path 'xxxxxx' already exists and is not an empty directory.
```

**Solution**: Manually delete the local repository clone from the filesystem (typically in `/tmp` or the working directory).


## Redis-Based Locking (Optional)

As an alternative to Git branch locking, the MAS CLI supports Redis-based distributed locking for environments that require higher performance or more frequent concurrent updates.

### Overview

Redis-based locking uses Redis's atomic operations to implement distributed locks. This approach offers several advantages over Git branch locking:

- **Lower latency**: No need to push/pull from remote Git repository
- **Better performance**: Faster lock acquisition and release
- **Native distributed locking**: Built-in support for distributed systems
- **Automatic expiration**: Locks can be configured to expire automatically

### Prerequisites

To use Redis-based locking, you need:

1. **Redis Server**: A Redis instance accessible from where the MAS CLI runs
2. **Redis Connection Details**: Host, port, and authentication credentials
3. **Network Access**: The CLI must be able to connect to the Redis server

### Setup

#### 1. Deploy Redis

You can deploy Redis in several ways:

**Option A: Redis on OpenShift/Kubernetes**
```bash
# Deploy Redis using a Helm chart or operator
# Ensure it's accessible from your CI/CD environment
```

**Option B: Managed Redis Service**
- AWS ElastiCache for Redis
- Azure Cache for Redis
- IBM Cloud Databases for Redis
- Google Cloud Memorystore for Redis

**Option C: Standalone Redis**
```bash
# Install Redis on a dedicated server
# Configure for network access and authentication
```

For detailed setup instructions, refer to the [Redis Locking Setup Guide](https://github.com/ibm-mas/cli/blob/master/docs/redis-locking-setup.md) in the MAS CLI repository.

#### 2. Configure Environment Variables

Set the following environment variables to enable Redis-based locking:

```bash
# Enable Redis locking
export GITOPS_USE_REDIS_LOCKING="true"

# Redis connection details
export REDIS_HOST="your-redis-host"
export REDIS_PORT="6379"
export REDIS_USERNAME="your-redis-username"
export REDIS_PASSWORD="your-redis-password"

# Optional: Redis TLS configuration
export REDIS_TLS="true"
export REDIS_TLS_CA_CERT="/path/to/ca-cert.pem"

# Optional: Lock timeout (seconds)
export REDIS_LOCK_TIMEOUT="300"
```

### How It Works

When Redis-based locking is enabled:

1. **Lock Acquisition**: The process attempts to set a key in Redis using `SET key value NX EX timeout`:
      - `NX`: Only set if key doesn't exist (atomic operation). 
      - `EX`: Set expiration time to prevent stuck locks  

2. **Lock Key Naming**: Similar to Git branch locks, Redis keys follow a pattern:  
   ```
   gitops:lock:<operation>:<account>:<cluster>[:<instance>]
   ```

3. **Retry Logic**: If the lock is held by another process, the CLI retries with exponential backoff

4. **Lock Release**: After completing the operation, the lock is explicitly deleted from Redis

5. **Automatic Expiration**: If a process crashes, the lock automatically expires after the timeout period

### Configuration Options

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `GITOPS_USE_REDIS_LOCKING` | Enable Redis-based locking (`true` or `false`) | `false` |
| `REDIS_HOST` | Redis server hostname | - |
| `REDIS_PORT` | Redis server port | `6379` |
| `REDIS_USERNAME` | Redis authentication username | - |
| `REDIS_PASSWORD` | Redis authentication password | - |
| `REDIS_TLS` | Enable TLS connection | `false` |
| `REDIS_TLS_CA_CERT` | Path to CA certificate for TLS | - |
| `REDIS_LOCK_TIMEOUT` | Lock expiration time in seconds | `300` |
| `REDIS_LOCK_RETRY_DELAY` | Delay between retry attempts in seconds | `5` |
| `REDIS_LOCK_MAX_RETRIES` | Maximum number of retry attempts | `60` |

### Advantages

- **Performance**: Significantly faster than Git branch locking
- **Scalability**: Better suited for high-frequency concurrent operations
- **Reliability**: Automatic lock expiration prevents permanent deadlocks
- **Visibility**: Lock status can be monitored directly in Redis
- **Flexibility**: Fine-grained control over timeout and retry behavior

### Limitations

- **External Dependency**: Requires a Redis server to be deployed and maintained
- **Network Dependency**: Requires network connectivity to Redis
- **Additional Complexity**: More infrastructure to manage and monitor
- **Cost**: May incur additional costs for managed Redis services

### Monitoring

You can monitor Redis locks using the Redis CLI:

```bash
# Connect to Redis
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD

# List all active locks
KEYS gitops:lock:*

# Check specific lock details
GET gitops:lock:gitops-suite:dev:cluster1:inst1

# Check lock TTL (time to live)
TTL gitops:lock:gitops-suite:dev:cluster1:inst1
```

### Troubleshooting Redis Locks

#### Stuck Locks

If a lock appears to be stuck:

1. **Check lock expiration**:  
   ```
   redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD TTL gitops:lock:<key>
   ```

2. **Manually delete stuck lock** (use with caution):  
   ```
   redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD DEL gitops:lock:<key>
   ```

#### Connection Issues

If the CLI cannot connect to Redis:

1. Verify Redis is running and accessible
2. Check firewall rules and network connectivity
3. Verify authentication credentials
4. Check SSL/TLS configuration if enabled

### Choosing Between Git and Redis Locking

| Factor | Git Branch Locking | Redis-Based Locking |
|--------|-------------------|---------------------|
| **Setup Complexity** | Simple (no additional infrastructure) | Moderate (requires Redis) |
| **Performance** | Slower (network I/O to Git) | Faster (in-memory operations) |
| **Concurrent Operations** | Suitable for low-medium frequency | Suitable for high frequency |
| **Lock Visibility** | Git branches | Redis keys |
| **Automatic Cleanup** | Exit traps | Automatic expiration |
| **External Dependencies** | None (Git already required) | Redis server required |
| **Best For** | Standard deployments, lower concurrency | High-frequency updates, CI/CD pipelines |

### Migration from Git to Redis Locking

To migrate from Git branch locking to Redis-based locking:

1. Deploy and configure Redis as described above
2. Set the `GITOPS_USE_REDIS_LOCKING=true` environment variable
3. Configure Redis connection details (host, port, password, TLS settings)
4. Test with a non-production environment first
5. Monitor for any stuck Git lock branches and clean them up
6. Roll out to production environments

No changes to your GitOps configuration files are required - only the locking mechanism changes.