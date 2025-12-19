# Python SDK Guide

The Secretariat Python SDK provides seamless integration for Python applications.

## Installation

```bash
pip install secretariat
```

Or with Poetry:

```bash
poetry add secretariat
```

## Quick Start

```python
from secretariat import Secretariat

# Create client
client = Secretariat()

# Get a single secret
api_key = client.get('OPENAI_API_KEY')
print(f'API Key: {api_key}')

# Get multiple secrets
secrets = client.get_many(['OPENAI_API_KEY', 'DATABASE_URL'])
print(f'OpenAI: {secrets["OPENAI_API_KEY"]}')

# List all secret names
names = client.list()
print(f'Available secrets: {names}')

# Clean up
client.close()
```

## Context Manager

The recommended way to use the SDK is with a context manager:

```python
from secretariat import Secretariat

with Secretariat() as client:
    api_key = client.get('OPENAI_API_KEY')
    # Connection automatically closed when exiting the block
```

## API Reference

### `Secretariat` Class

The main client class for interacting with the Secretariat daemon.

#### Constructor

```python
Secretariat(
    socket_path: Optional[str] = None,
    timeout: float = 5.0
)
```

**Parameters:**
- `socket_path` - Custom path to Unix socket (optional)
- `timeout` - Request timeout in seconds (default: 5.0)

#### Methods

##### `get(key: str) -> str`

Retrieve a single secret value.

```python
api_key = client.get('OPENAI_API_KEY')
```

**Raises:** `SecretariatError` if:
- Secret not found
- Permission denied
- Daemon not running

##### `get_many(keys: List[str]) -> Dict[str, str]`

Retrieve multiple secrets at once.

```python
secrets = client.get_many(['OPENAI_API_KEY', 'DATABASE_URL'])
openai_key = secrets['OPENAI_API_KEY']
```

##### `list() -> List[str]`

List all available secret names.

```python
secret_names = client.list()
print(f'Found {len(secret_names)} secrets')
```

##### `close() -> None`

Close the connection to the daemon.

```python
client.close()
```

### Convenience Functions

#### `get(key: str) -> str`

Quick function for one-off secret retrieval:

```python
from secretariat import get

api_key = get('OPENAI_API_KEY')
```

#### `get_or_env(key: str, env_var: Optional[str] = None) -> str`

Get secret with environment variable fallback:

```python
from secretariat import get_or_env

# Falls back to OPENAI_API_KEY env var if daemon unavailable
api_key = get_or_env('OPENAI_API_KEY')

# Use different env var name
api_key = get_or_env('OPENAI_API_KEY', env_var='MY_OPENAI_KEY')
```

### `SecretariatError` Exception

```python
class SecretariatError(Exception):
    message: str
    code: Optional[int]
```

## Integration Examples

### FastAPI

```python
from fastapi import FastAPI, Depends
from secretariat import Secretariat

app = FastAPI()

# Create a dependency
def get_secrets():
    with Secretariat() as client:
        yield client

@app.get("/")
async def root(secrets: Secretariat = Depends(get_secrets)):
    api_key = secrets.get('OPENAI_API_KEY')
    return {"status": "ok"}
```

### Flask

```python
from flask import Flask, g
from secretariat import Secretariat

app = Flask(__name__)

def get_client():
    if 'secretariat' not in g:
        g.secretariat = Secretariat()
    return g.secretariat

@app.teardown_appcontext
def close_client(error):
    client = g.pop('secretariat', None)
    if client is not None:
        client.close()

@app.route('/')
def index():
    client = get_client()
    api_key = client.get('OPENAI_API_KEY')
    return 'OK'
```

### Django

```python
# settings.py
from secretariat import get_or_env

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': 'localhost',
        'NAME': 'mydb',
        'USER': get_or_env('DB_USER'),
        'PASSWORD': get_or_env('DB_PASSWORD'),
    }
}

# Or lazy loading
from secretariat import Secretariat

class SecretsMixin:
    _client = None

    @classmethod
    def get_client(cls):
        if cls._client is None:
            cls._client = Secretariat()
        return cls._client

    @classmethod
    def get_secret(cls, key):
        return cls.get_client().get(key)
```

### LangChain / OpenAI

```python
from openai import OpenAI
from secretariat import get

# Initialize OpenAI with secret
client = OpenAI(api_key=get('OPENAI_API_KEY'))

response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### SQLAlchemy

```python
from sqlalchemy import create_engine
from secretariat import get

# Build connection string with secrets
db_url = f"postgresql://{get('DB_USER')}:{get('DB_PASSWORD')}@localhost/mydb"
engine = create_engine(db_url)
```

### Boto3 (AWS)

```python
import boto3
from secretariat import Secretariat

with Secretariat() as client:
    session = boto3.Session(
        aws_access_key_id=client.get('AWS_ACCESS_KEY_ID'),
        aws_secret_access_key=client.get('AWS_SECRET_ACCESS_KEY'),
        region_name='us-east-1'
    )

    s3 = session.client('s3')
```

## Async Support

The SDK also supports async operations:

```python
import asyncio
from secretariat import AsyncSecretariat

async def main():
    async with AsyncSecretariat() as client:
        api_key = await client.get('OPENAI_API_KEY')
        print(f'API Key: {api_key}')

asyncio.run(main())
```

## Type Hints

The SDK is fully typed for use with mypy:

```python
from secretariat import Secretariat, SecretariatError
from typing import Dict

def get_config() -> Dict[str, str]:
    with Secretariat() as client:
        return client.get_many([
            'OPENAI_API_KEY',
            'DATABASE_URL',
        ])
```

## Best Practices

### 1. Use Context Managers

```python
# ✅ Good: Automatic cleanup
with Secretariat() as client:
    secret = client.get('KEY')

# ❌ Bad: Manual cleanup required
client = Secretariat()
secret = client.get('KEY')
client.close()  # Easy to forget!
```

### 2. Don't Store Secrets in Variables

```python
# ❌ Bad: Secret persists in memory
API_KEY = get('OPENAI_API_KEY')

# ✅ Good: Fetch when needed
def make_api_call():
    with Secretariat() as client:
        api_key = client.get('OPENAI_API_KEY')
        # Use immediately
        return requests.get(url, headers={'Authorization': f'Bearer {api_key}'})
```

### 3. Handle Errors Gracefully

```python
from secretariat import Secretariat, SecretariatError

try:
    with Secretariat() as client:
        api_key = client.get('OPENAI_API_KEY')
except SecretariatError as e:
    if 'not found' in e.message.lower():
        print(f'Secret not configured. Run: sec set OPENAI_API_KEY <value>')
    elif 'connect' in e.message.lower():
        print('Daemon not running. Start with: secd')
    else:
        raise
```

### 4. Use Environment Fallback for CI/CD

```python
from secretariat import get_or_env

# Works locally with daemon, and in CI with env vars
api_key = get_or_env('OPENAI_API_KEY')
```

## Troubleshooting

### Connection Failed

```python
try:
    client = Secretariat()
    client.get('KEY')
except SecretariatError as e:
    if 'connect' in str(e).lower():
        print('Start the daemon: secd')
```

### Permission Denied

Make sure your app is registered:

```bash
sec grant my-python-app OPENAI_API_KEY
```

### Socket Path Issues

Specify custom socket path if needed:

```python
client = Secretariat(socket_path='/custom/path/secretariat.sock')
```

## Testing

### Mocking in Tests

```python
import pytest
from unittest.mock import MagicMock, patch

@patch('secretariat.Secretariat')
def test_my_function(mock_secretariat):
    mock_client = MagicMock()
    mock_client.get.return_value = 'test-api-key'
    mock_secretariat.return_value.__enter__.return_value = mock_client

    result = my_function_that_uses_secrets()

    mock_client.get.assert_called_once_with('OPENAI_API_KEY')
```

### Integration Testing

```python
import pytest
from secretariat import Secretariat

@pytest.fixture
def secrets():
    with Secretariat() as client:
        yield client

def test_can_retrieve_secret(secrets):
    # Requires daemon running with test secret
    value = secrets.get('TEST_SECRET')
    assert value is not None
```
