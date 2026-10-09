# OGCR-Smart-Contracts

Smart contracts for the OGCR digital carbon registry (DCR). Each token carries a
snapshot of a registry record plus a link back to it (`_url` / `_uri`) and an
integrity hash (`_hash`, keccak256 of the registry's response body).

The [tokenizer](https://github.com/TESOBE/ogcr-tokenizer) mints these
tokens from registry records; the
[chain cache](https://github.com/TESOBE/OGCR-chain-cache) mirrors them
back into the registry.

## Token family

```
ParcelNFT ──────────────┐
                        ▼
                   ActivityNFT ◀── CertificationNFT   (one per certificate; a
                        ▲                              re-certification adds one)
                        │
            CarbonCreditBatchNFT ── owns ──▶ token-bound account (ERC-6551)
                                                   │ holds
                                                   ▼
                                             CarbonCredit (ERC-20)
```

| Contract | Standard | One token per | Minted when |
|---|---|---|---|
| `ParcelNFT` | ERC-721 | `parcel_id` | `parcel_owner_verification` is verified |
| `ActivityNFT` | ERC-721 | `activity_id` | `activity_verification` is verified and a `certificate_of_compliance` exists |
| `CertificationNFT` | ERC-721 | `certificate_of_compliance_id` | a `certificate_of_compliance` is created, including each re-certification |
| `CarbonCreditBatchNFT` | ERC-721 + ERC-6551 | `carbon_credit_batch_id` | an `activity_monitoring_period_verification` carries a value for a benefit field |
| `CarbonCredit` | ERC-20 | — | minted into a batch's token-bound account, `amount` of the batch |
| `CarbonERC6551Registry`, `CarbonERC6551Account` | ERC-6551 | — | infrastructure for the batch accounts |

Every token contract has an `owner` (can change the minter) and a single
`minter` (the tokenizer's key). `mint` takes the recipient and the token's data
struct.

### Fields

**ParcelNFT** — `parcel_id`, `parcel_uri`, `parcel_hash`.

**ActivityNFT** — `activity_id`, `operator_id`, `operator_name`, `name`,
`summary`, `website`, `activity_type`, `unit_types`, `city`, `country_id`,
`certification_scheme_id`, `parcel_ids[]`, `start_date`, `end_date`,
`activity_url`, `activity_hash`.

**CertificationNFT** — `certificate_of_compliance_id`,
`certificate_of_compliance_uri/hash`, `activity_id`, `activity_nft_id`,
`activity_uri/hash`, `activity_name`, `certification_scheme_name`,
`certification_scheme_uri/hash`, `certification_body_name`,
`certification_body_uri/hash`, `country_id`, `issue_date`, `expiry_date`,
`audit_report_uri/hash`, `carbon_removals_under_baseline`,
`soil_emissions_under_baseline`, `permanent_net_carbon_removal_benefit`,
`carbon_farming_temporary_net_carbon_removal_benefit`,
`carbon_farming_net_soil_emission_reduction_benefit`,
`carbon_storage_temporary_net_carbon_removal_benefit`, `unit_types`,
`certification_status`.

The quantities are decimal strings exactly as recorded on the certificate
(tonnes CO2e). An empty string means the certificate carries no value for that
quantity, and `tokenURI` leaves it out.

**CarbonCreditBatchNFT** — `carbon_credit_batch_id`, `batch_name`, `activity_id`,
`activity_nft_id`, `activity_name`, `activity_url/hash`, `country_id`,
`operator_url/hash`, `certificate_of_compliance_uri/hash`, `unit_type`,
`monitoring_period_start_date`, `monitoring_period_end_date`, `amount`,
`status_code`, `issue_date`, `expiry_date`, `certification_scheme_url/hash`,
`certification_body_url/hash`.

`amount` is the number of units issued for the batch, fixed at mint, in
CarbonCredit base units (18 decimals): 6.5 tonnes is `6500000000000000000`. The
live balance is the token-bound account's `CarbonCredit.balanceOf`.

| Benefit field on the verification | `batch_name` | `unit_type` |
|---|---|---|
| `permanent_net_carbon_removal_benefit` | Permanent Removals Carbon Credit Batch | Permanent Removal |
| `carbon_farming_temporary_net_carbon_removal_benefit` | Carbon Farming Removals Carbon Credit Batch | Carbon Farming Sequestration |
| `carbon_farming_net_soil_emission_reduction_benefit` | Soil Emissions Reductions Carbon Credit Batch | Soil Emission Reduction |
| `carbon_storage_temporary_net_carbon_removal_benefit` | Carbon Storage in Product Carbon Credit Batch | Carbon Storage in Product |

**CarbonCredit** — besides ERC-20, `mintedTo(address)` is the cumulative amount
ever minted to an address. The tokenizer funds a batch against that, not against
the balance, so credits the owner has moved out are never issued a second time.

## Build and test

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

forge build
forge test
```

## Deploy

```bash
PRIVATE_KEY=0x... \
MINTER_ADDRESS=0x...            `# the tokenizer's address; default: the deployer` \
PARCEL_CONTRACT_ADDRESS=0x...   `# optional: keep an already deployed ParcelNFT` \
forge script script/DeployTokenSystem.s.sol \
  --rpc-url $RPC_URL --broadcast --legacy
```

It writes every address to `deployments/token-system-<chain id>.env`, in the
variable names the tokenizer and the chain cache read.

Token data is fixed in each contract's storage layout, so a change to a token's
fields means a new deployment of that contract; tokens minted on the previous
one stay where they are.

### Local chain

```bash
anvil --chain-id 2025
forge script script/local/DeployLocalStack.s.sol \
  --rpc-url http://127.0.0.1:8545 --broadcast --legacy
```

Deploys the whole family and mints one coherent set of records (two parcels, an
activity, a certificate, two credit batches with their credits). Addresses go to
`deployments/local-anvil.env`. The chain cache's integration tests run against
this fixture.

## Reading a token

```bash
cast call $ACTIVITY_CONTRACT_ADDRESS "tokenIdByActivityId(string)(uint256)" "<activity_id>" --rpc-url $RPC_URL
cast call $ACTIVITY_CONTRACT_ADDRESS "tokenURI(uint256)(string)" 1 --rpc-url $RPC_URL
# → data:application/json;base64,... (base64-decode to read name + attributes)
```

Lookups by business key: `ParcelNFT.tokenIdByParcelId`,
`ActivityNFT.tokenIdByActivityId`, `CertificationNFT.tokenIdByComplianceId`,
`CarbonCreditBatchNFT.tokenIdByBatchId`. Each returns 0 for an id that has not
been minted.

## Links

- **[ERC6551 Standard](https://eips.ethereum.org/EIPS/eip-6551)** - Token Bound Accounts
- **[OpenZeppelin](https://openzeppelin.com/)** - Smart contract framework
