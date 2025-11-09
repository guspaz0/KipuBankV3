# instrucciones para foundry

## Requisitos:
- Instalacion dependencias:
```bash
# contratos de openzeppelin (interfaces utiles)
forge install openzeppelin/openzeppelin-contracts

#chainlink Contracts (oraculo)
forge install smartcontractkit/chainlink-local
forge install smartcontractkit/foundry-chainlink-toolkit

# dependencia foundry para testing
forge install foundry-rs/forge-std

# dependencias uniswap
forge install Uniswap/swap-router-contracts
forge install uniswap/v4-periphery
forge install uniswap/permit2
forge install uniswap/universal-router
forge install uniswap/v3-core
forge install uniswap/v2-core

```

- remapping dependencias:

```bash
forge remappings
```
o bien, **recomendado**, crear archivo `foundry.toml` en la raiz del proyecto con los siguientes contenidos:
```toml
# Ejemplo de remappings en foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "@chainlink/contracts/=lib/foundry-chainlink-toolkit/src/",
    "@chainlink-local/src/=lib/chainlink-local/src/",
    "forge-std=lib/forge-std/src",
    "@swap/contracts/=lib/swap-router-contracts/contracts/",
    "@uniswap/v4-periphery/=lib/v4-periphery/",
    "@uniswap/permit2/=lib/permit2/",
    "@uniswap/universal-router/=lib/universal-router/",
    "@uniswap/v3-core/=lib/v3-core/",
    "@uniswap/v2-core/=lib/v2-core/"
]
```

## Desarrollo:

- Correr tests:
```bash
forge test
```

