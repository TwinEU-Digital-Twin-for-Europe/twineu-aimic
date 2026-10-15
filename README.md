# TwinEU AI Models & Services Integration Component

This microservice acts as a publisher bridge. If you have an AI Model, a custom Web App, or a Dataset that you want to monetize on the TwinEU Marketplace, you can use this component to publish it.

It automatically registers your asset into the central **TwinEU Federated Catalog**, injects your pricing, and bundles the exact orchestration rules the TwinEU Workbench needs to securely deploy your asset for buyers.

---

## How to Publish an Asset (End-User Guide)

### Step 1: Prepare Your Asset

Ensure your file follows the strict extension rules. For example, if you are publishing a Scikit-Learn model, save your weights as `model.pkl`.

### Step 2: Fire the Registration Command

You will use `curl` to send a `multipart/form-data` request to this component. You attach your physical file using `-F "file=@..."` and provide the configuration rules in a stringified JSON object using `-F "metadata_json=..."`.

**Example: Publishing a Wind Forecasting Model**
Run this in the same directory as your `model.pkl` file:

```bash
curl -X POST http://localhost:8100/register/artifact \
  -F "file=@model.pkl" \
  -F "metadata_json={
    \"id\": \"test-wind-power-forecast-001\",
    \"title\": \"Wind Power Production Forecasting Engine\",
    \"description\": \"Sklearn model for predicting wind power generation\",
    \"version\": \"1.0.0\",
    \"business_object_name\": \"Forecast data (load, generation, FSP)\",
    \"market_billable\": true,
    \"market_price\": 0.5,
    \"deployment_ready\": true,
    \"workbench_artifact_type\": \"AI_MODEL\",
    \"workbench_framework\": \"sklearn\",
    \"workbench_cpu\": \"500m\",
    \"workbench_memory\": \"1024Mi\"
  }"

```
### Alternative: Publishing directly from BDMM Shared Storage
If you are running this component alongside the TwinEU Big Data Management Module (BDMM), you do not need to have the actual file to your laptop to publish them. You can bypass the `file` upload and provide a `storage_uri` instead.

**Example: Publishing from MinIO**
```bash
curl -X POST http://localhost:8100/register/artifact \
  -F "storage_uri=minio://batch-data/my-sensor/2026/08/06/dataset.json" \
  -F "metadata_json={
    \"id\": \"dataset-001\",
    \"title\": \"Historical Grid Demand 2026\",
    \"version\": \"1.0.0\",
    \"business_object_name\": \"Settlement Data\",
    \"market_billable\": false,
    \"deployment_ready\": false
  }"
```
*(Supported prefixes: `minio://[bucket]/[path]` and `local://[absolute_path]`)*

### Step 3: Verify on the Marketplace

If the command succeeds, it will return a new `data_offering_id`. Your asset is now live in the TwinEU Federated Catalog. When a consumer buys it, the Marketplace will read your `workbench_...` rules and automatically spin up an MLServer REST API for them.

---

## Publishing Requirements & Compatibility Matrix

To successfully publish an asset that the Workbench can execute, you must match your input file format with the correct `workbench_artifact_type`.

### Compatibility Matrix

| What you want to deploy... | Physical Input Format | Required `workbench_artifact_type` | Can be Batch Job? | K8s Output |
| --- | --- | --- | --- | --- |
| **Custom Web App / API** | `.zip` or `.tar.gz` | `DIGITAL_SERVICE` | ❌ No | Deployment + Ingress |
| **Custom Web App (Pre-built)** | Public/Private Registry URL | `CONTAINER_IMAGE` | ❌ `false` (Default) | Deployment + Ingress |
| **Web App (Air-Gapped)** | `.tar` (Exported Image) | `CONTAINER_IMAGE` | ❌ `false` (Default) | Skopeo ➔ Deployment + Ingress |
| **Data Pipeline / Cron Task** | Public/Private Registry URL | `CONTAINER_IMAGE` | ✅ `true` | K8s Job Only |
| **Data Pipeline (Air-Gapped)** | `.tar` (Exported Image) | `CONTAINER_IMAGE` | ✅ `true` | Skopeo ➔ K8s Job Only |
| **Naked AI Model Weights** | `.pkl`, `.onnx`, `.pt` | `AI_MODEL` | ❌ No | Deployment + Ingress |
| **Auto-ETL Dashboard** | `.csv` or `.json` | `DATA_VISUALIZATION` | ❌ No | InitContainer ➔ Deployment + Ingress |

### Strict Zero-Trust Packaging Rules

The TwinEU Workbench operates a strict Zero-Trust Kubernetes environment. Assets must adhere to these rules before registration:

* **Strict File Extensions:** The Workbench strictly enforces file extensions to build extraction scripts.
* `DIGITAL_SERVICE`: `.zip`, `.tar.gz`, `.tar`, `.tgz`.
* `AI_MODEL`: `.pkl`, `.h5`, `.pt`, `.onnx`, `.joblib`, `.sav`.
* `DATA_VISUALIZATION`: `.csv`, `.json`, `.db`, `.sqlite`, or compressed archives.
* `CONTAINER_IMAGE` (Air-gapped): `.tar` or `.tar.gz`.


* **Network Binding (`DIGITAL_SERVICE`):** The application server within your code archive **must bind to `0.0.0.0**` (not `localhost` or `127.0.0.1`). Binding to localhost prevents Kubernetes from routing traffic, resulting in a 502 Bad Gateway.
* **Zero-Trust Security Context (`CONTAINER_IMAGE`):** The cluster strictly prohibits containers from running as the `root` user (UID 0). Your Dockerfile **must** define a non-root user (e.g., `USER 1000`) before the entrypoint, otherwise it will instantly trigger a `CreateContainerError`.
* **File Size Limit (Default: 500MB):** Due to architectural constraints on the TwinEU DSP Connector (which requires physical files to be Base64-encoded within a JSON payload), this component enforces a default maximum file size of 500MB. Attempting to publish larger datasets will result in a `413 Payload Too Large` error. Providers can adjust this limit via the `MAX_FILE_SIZE_BYTES` variable in the `.env` file, but be aware that increasing it drastically raises the risk of Out-Of-Memory (OOM) crashes.

---

## Exhaustive Payload Examples

Below are the exact `metadata_json` configuration blocks for every deployment typology supported by the TwinEU Workbench.

### 1. AI Models (Zero-MLOps Engine)

Registers a naked model weight file. The Workbench automatically wraps it in a standardized V2 Inference Protocol server (e.g., MLServer or Triton).

```json
{
  "id": "demand-forecaster-001",
  "title": "Demand Forecast Model v2",
  "business_object_name": "Forecast data (load, generation, FSP)",
  "market_billable": true,
  "market_price": 0.5,
  "version": "1.0.0",
  "deployment_ready": true,
  "workbench_artifact_type": "AI_MODEL",
  "workbench_framework": "onnx"
}

```

### 2. Digital Services (Raw Code Archives)

Registers a custom web application archive (`.zip`), configuring the NGINX Auth-Proxy routing on the Workbench.

```json
{
  "id": "data-cleaner-api", 
  "title": "Data Cleaner Service",
  "business_object_name": "Generic",
  "market_billable": true,
  "market_price": 1.2,
  "version": "1.0.0",
  "deployment_ready": true,
  "workbench_artifact_type": "DIGITAL_SERVICE",
  "workbench_runtime_env": "python",
  "workbench_port": 5000
}

```

### 3. Data Visualization (Auto-ETL Ad-Hoc Mode)

Registers a raw dataset (`.csv`). Using `ad_hoc` instructs the Workbench to automatically parse the raw file into an ephemeral memory-safe SQLite database before booting the dashboard engine.

```json
{
  "id": "test-market-prices-viz-001",
  "title": "European Market Prices Dashboard",
  "business_object_name": "Settlement Data",
  "market_billable": true,
  "market_price": 0.1,
  "version": "1.0.0",
  "deployment_ready": true,
  "workbench_artifact_type": "DATA_VISUALIZATION",
  "workbench_engine": "metabase",
  "workbench_provisioning_mode": "ad_hoc",
  "workbench_port": 3000
}

```

### 4. Data Visualization (Pre-Configured Archive Mode)

Registers a `.zip` containing pre-configured dashboard JSONs and a `provider.yml` for instant Grafana provisioning.

```json
{
  "id": "grafana-bundle-001",
  "title": "Interconnector Telemetry Suite",
  "business_object_name": "Network information",
  "market_billable": true,
  "market_price": 0.5,
  "version": "1.0.0",
  "deployment_ready": true,
  "workbench_artifact_type": "DATA_VISUALIZATION",
  "workbench_engine": "grafana",
  "workbench_provisioning_mode": "archive",
  "workbench_port": 3000
}

```

### 5. Data Visualization (Live External Database)

Registers a dashboard that points directly to a live, external database instead of an uploaded file.
*(Note: Do not include database passwords here! The `live_db` mode signals the Marketplace frontend to securely prompt the buyer for their database credentials via a UI modal at the exact moment of deployment).*

```json
{
  "id": "live-sensor-viz",
  "title": "Live Sensor Telemetry Dashboard",
  "business_object_name": "Meter Data",
  "market_billable": true,
  "market_price": 0.2,
  "version": "1.0.0",
  "deployment_ready": true,
  "workbench_artifact_type": "DATA_VISUALIZATION",
  "workbench_engine": "grafana",
  "workbench_provisioning_mode": "live_db",
  "workbench_port": 3000
}

```

### 6. Container Images (Batch Job / Data Pipeline)

Registers a Docker container that executes a heavy computational task once and terminates gracefully, bypassing web networking entirely.

```json
{
  "id": "grid-optimizer-job",
  "title": "Overnight Grid Optimization Task",
  "business_object_name": "Resource  optimization information",
  "market_billable": true,
  "market_price": 2.0,
  "version": "1.0.0",
  "deployment_ready": true,
  "workbench_artifact_type": "CONTAINER_IMAGE",
  "workbench_is_batch_job": true,
  "workbench_max_runtime_seconds": 3600
}

```

### 7. Container Images (Private Registry Web App)

Registers a containerized web application residing in a secure private registry. The Workbench automatically generates Kubernetes `imagePullSecrets` upon deployment.

```json
{
  "id": "proprietary-analytics-app",
  "title": "Proprietary Analytics UI",
  "business_object_name": "Generic",
  "market_billable": true,
  "market_price": 5.0,
  "version": "1.0.0",
  "deployment_ready": true,
  "workbench_artifact_type": "CONTAINER_IMAGE",
  "workbench_is_batch_job": false,
  "workbench_port": 8080,
  "workbench_registry_server": "my-private-registry.com",
  "workbench_registry_username": "robot-deploy-user",
  "workbench_registry_password": "secure-registry-token"
}

```
## Domain Categories (`business_object_name`)

The TwinEU Data Space strictly categorizes assets by Energy Domain.

You do **not** need to memorize UUIDs. On startup, this component dynamically connects to the TwinEU Middleware, paginates through the `cross_platform_service_business_objects` catalog, and builds a live mapping dictionary.

Simply provide the exact human-readable name of the category in your JSON payload (e.g., `"business_object_name": "Forecasts"`). The component automatically translates this into the correct `cf_id` and `category_code` required by the Middleware and DSP Connector.

## Ecosystem Integration

This component does not deploy code itself; it acts as the programmatic **Publisher**. It feeds the rest of the TwinEU ecosystem:

1. **The TwinEU Marketplace:** The Marketplace UI reads the central Middleware. By parsing the JSON string injected by this component, the Marketplace automatically knows if the asset is a static download or a deployable service, renders the appropriate UI buttons, and handles IDSA negotiation.
2. **The Services Workbench:** When a consumer deploys the asset, the Marketplace routes the request to the Workbench. The Workbench securely fetches the physical file from your local DSP Connector and orchestrates the Kubernetes pods based strictly on the `workbench_` parameters you provided during registration.

---

## Architecture

This component implements a strict 2-step decentralized publishing flow:

1. **Central Metadata Registration:** It authenticates with the Central TwinEU Middleware (Federated Catalog) and creates a data offering. It dynamically injects the necessary Kubernetes orchestration parameters (CPU, Framework, etc.) into the `comments` field so the Marketplace UI knows exactly how to handle the asset.
2. **Local Physical Hosting:** It takes the uploaded physical file, Base64 encodes it, and pushes it directly to the provider's **Local DSP Connector** via the `POST /api/provide-data` endpoint. The physical file never touches the central catalog; it remains securely in the provider's local MinIO node until a consumer successfully negotiates access.

## Data Flow

1. **Validation**: Enforces strict Pydantic schemas to ensure all assets meet the requirements of the TwinEU Marketplace and the Services Workbench.
2. **Serialization**: Transforms the payload into the exact structure required by the TwinEU Middleware (`data_catalog_data_offerings`), safely stringifying orchestration rules into the `comments` field.
3. **Authentication**: Performs machine-to-machine (M2M) JWT authentication with the IAM service.
4. **Publication**: Registers the asset directly to the Federated Catalog via `PUT /api/dataset/my_offered_services`.
5. **Persistence**: Saves a local SQLite record mapping the internal ID to the newly generated Middleware ID.

```text
┌─────────────────┐      ┌─────────────────────┐      ┌─────────────────────┐
│Models / Services│───▶  │   AI Integration    │───▶  │  TwinEU Middleware  │
│ (Local/CI/CD)   │      │   Component         │      │  (Federated Catalog)│
└─────────────────┘      └─────────────────────┘      └─────────────────────┘
                                    │                           │
                                    ▼                           ▼
                           ┌─────────────────┐        ┌─────────────────────┐
                           │   Local DB      │        │ TwinEU Marketplace  │
                           │   (Mapping)     │        │ & Service Workbench │
                           └─────────────────┘        └─────────────────────┘

```

### Prerequisites

* Python 3.10+
* Docker & Docker Compose

### Configuration (Environment Variables)

This component connects directly to the TwinEU infrastructure.

```bash
# TwinEU Middleware Connection
MIDDLEWARE_URL=http://4.232.76.64/middleware-dev
MIDDLEWARE_USER=your_provider_username
MIDDLEWARE_PASS=your_provider_password

# Local Database
DB_PATH=./data/models.db

```
### Start the Service

Once your environment variables are configured, you can launch the publisher component using the provided Makefile:

```bash
# Start the service in the background
make up

# View the live logs
make logs

```

OR

```bash
docker compose up -f docker-compose.prod.yaml -d

```

### Error Handling

* `400 Bad Request` - Invalid domain category. Ensure the `business_object_name` exactly matches the active TwinEU Middleware dictionary.
* `409 Conflict` - Asset ID already exists in the local mapping database.
* `422 Unprocessable Entity` - Invalid metadata (e.g., missing framework for an `AI_MODEL`).
* `502 Bad Gateway` - Failed to authenticate or communicate with the TwinEU Middleware.

### ⚠️ Edge Deployment: Docker Volume Permissions
This component utilizes local storage volumes (`./aimic_data` for the SQLite database and `./local_staging` for physical file access) mounted from your host machine.
* **Symptom:** The container throws `EACCES: permission denied` errors when trying to write to the local mapping database or read a physical file.
* **Fix:** If your host machine runs Docker in rootless mode or enforces strict user namespaces, ensure the mounted directories are writable by the container. Before starting the service, run:
```bash
mkdir -p aimic_data local_staging
chmod -R 777 aimic_data local_staging
```

## Going Live (Production Deployment Checklist)

Out of the box, this service binds to local ports over standard HTTP. To safely expose the publisher API to your internal network or CI/CD pipelines, you must wrap the deployment in standard web infrastructure:

* **Reverse Proxy & SSL/TLS:** Place a reverse proxy (such as NGINX, Traefik, or Apache) in front of the service. **HTTPS is highly recommended** for production, as the API may transmit sensitive data or tokens.
* **Firewall Restrictions:** Only expose the public-facing API port (`8100`) to trusted IP addresses or secure subnets.
* **Protect the Database:** Ensure the `./aimic_data` volume is strictly protected at the host OS level. It contains the mapping database which holds the state of your published TwinEU assets.
