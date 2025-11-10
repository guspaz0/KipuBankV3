# KipuBankV3 Smart Contract

- [Deploy contrato sepolia testnet](https://sepolia.etherscan.io/address/0x1f66459e0054ba61707af12b930a9cfd883ecb48)
- Contract address: `0x1f66459e0054Ba61707af12b930A9CFd883Ecb48`

## Descripción General

KipuBankV3 es un contrato inteligente de Solidity que permite a los usuarios depositar y retirar ETH, tokens ERC20 y USDC a través de Uniswap V2. También incluye funciones administrativas exclusivas para el propietario para actualizar direcciones críticas.

### Características Clave
- Depositar ETH, Tokens ERC20 o USDC en el contrato.
- Retirar fondos en USDC.
- Ownable: Solo el propietario puede actualizar configuraciones críticas como el router de Uniswap y la dirección de USDC.
- SafeERC20 para transferencias de tokens seguras.

## Uso

### Requisitos Previos
- Asegúrate de tener [Foundry](https://github.com/foundry-rs/foundry) instalado.

### Compilación

```bash
forge build
```

### Pruebas

Ejecutar las pruebas para asegurarse de que todo funcione como se espera:

```bash
forge test
```

### Despliegue

Para desplegar el contrato, puedes usar el siguiente comando de Foundry. Asegúrate de reemplazar `DEPLOYER_PRIVATE_KEY`, `BANK_CAP` y `UNISWAP_ROUTER` con los valores apropiados en el archivo .env.

- **Deploy local**_
```bash
# Deployay nodo local con foundry
anvil

# Deploy contracto kipubank en nodo local
forge script script/Deploy.s.sol:DeployKipuBankV3 --rpc-url http://127.0.0.1:8545 -vvvv --broadcast
```
- **Deploy en Sepolia**
```bash
# deploy sepolia testnet y verificacion con foundry
forge script script/Deploy.s.sol:DeployKipuBankV3 --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast --verify --etherscan-api-key <CAMBIAR_POR_TU_API_KEY> -vvv
```

## Funciones del Contrato

### Depósito

#### `deposit(address _tokenAddress, uint256 _tokenAmount, uint256 minUsdcOut, uint256 deadline)`
Deposita ETH o tokens ERC-20 y los cambia automáticamente por tokens USDC a través de Uniswap V2. La cantidad mínima de USDC a recibir debe especificarse.

### Retiro

#### `withdraw(uint256 _amountUsdc)`
Retira la cantidad especificada de USDC del saldo del usuario en el contrato.

## Eventos
- **DepositSwapped**: Emitido cuando un depósito es cambiado por USDC.
- **DepositUsdc**: Emitido cuando se deposita USDC directamente en el banco.
- **WithdrawUsdc**: Emitido cuando ocurre un retiro.
- **RouterUpdated**: Emitido cuando se actualiza la dirección del router de Uniswap.
- **UsdcUpdated**: Emitido cuando se actualiza la dirección del contrato del token USDC.



## Desarrollo

Para desarrollar en este proyecto, clona el repositorio e instala las dependencias:

```bash
git clone <repository_url>
cd kipubankv3
forge build
```