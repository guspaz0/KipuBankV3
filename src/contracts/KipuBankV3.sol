// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*//////////////////
        Imports
//////////////////*/
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*///////////////////////
        Libraries
///////////////////////*/
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*///////////////////////
        Interfaces
///////////////////////*/
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

/**
 * @title KipuBank
 * @author Gustavo R. Paz
 * @dev Smart contract para gestionar un banco sencillo donde los usuarios pueden depositar y retirar ETH.
 */
contract KipuBankV3 is Ownable, ReentrancyGuard {
    /*///////////////////////
        TYPE DECLARATIONS
    ///////////////////////*/
    using SafeERC20 for IERC20;

    /*//////////////////////////////
          Variables de estado
    ///////////////////////////////*/

    /// @notice Uniswap V2 router instance used for swaps.
    IUniswapV2Router02 public i_router;

    /// @notice Uniswap V2 factory instance derived from the router.
    IUniswapV2Factory public i_factory;

    /// @notice Wrapped ETH (WETH) address used by Uniswap.
    address public immutable WETH;
    /// @notice Address del token USDC usado como unidad de medida.
    address public s_usdc;

    /// @notice Total USDC currently held by the contract.
    uint256 public totalUsdc;

    /// @notice Mapping of user addresses to their USDC-denominated balances.
    mapping(address => uint256) public balanceOfUsdc;

    /// @notice Límite por transacción de retiro (en usdc)
    uint256 public immutable withdrawLimitUSD = 1000;

    /// @notice constante para almacenar la dirección del token ETH en el sistema
    address constant ETH_ADDRESS = address(0);

    /// @notice Limite global de depositos en USD;
    uint256 public immutable bankCap;

    /// @notice contador retiros
    uint128 public withdrawalCount = 0;

    /// @notice contador depositos
    uint128 public depositosCount = 0;

    /*//////////////////////////////
            Errores
    ///////////////////////////////*/

    /// @notice Error personalizado para manejo de fondos insuficientes
    error InsufficientUserBalance(uint256 requested, uint256 available);

    /// @notice Error personalizado para manejo de valores no válidos
    error ZeroAmount();

    error ZeroAddress();

    /// @notice Error personalizado para manejo de llamadas no autorizadas
    error Reentrancy();

    /// @notice Error personalizado para manejo de excedentes del límite del banco
    error BankCapLimitExceeded(uint256 bankCap);

    /// @notice Error que se emite al intentar validar un address
    error Bank_invalidAddress(address _address);

    /// @notice Error que se emite al intentar agregar un token que ya existe dentro del catalogo
    error Bank_TokenAlreadySupported(address _address);
    
    /// @notice Error que se emite al intentar operar con un token no soportado
    error UnsupportedToken(address _token);

    /// @notice Error personalizado para manejo de errores en el limite de retiro
    error WithdrawalLimitExceeded(uint256 _withdrawLimit, uint256 _attemptedWithdrawal);

    /// @notice Error personalizado para manejo de errores en los depositos
    error DepositAmountMismatch(
        address caller,
        uint256 expectedValue,
        uint256 _amount
    );

    /// @notice Error personalizado para manejo de errores en el los depositos fallbacks (receive)
    error ReceiveFallbackDepositError(address caller, uint256 value);

    /// @notice Error personalizado para manejo de errores en el los depositos fallbacks (fallback)
    error FallbackDepositError(address caller, uint256 value);

    /// @notice Error personalizado para manejo de errores en los parametros del constructor
    error ConstructorError(string parameter);

    /*//////////////////////////////
            Eventos
    ///////////////////////////////*/

    /// @notice Evento que se emite cuando se realiza un depósito con tokens o eth nativo
    event DepositSwapped(address indexed _user, address _tokenIn, uint256 _amountIn, uint256 _usdcReceived);
    
    /// @notice Evento que se emite cuando se realiza un depósito en USDC
    event DepositUsdc(address indexed user, uint256 _amount);

    /// @notice Evento que se emite cuando se realiza un retiro
    event WithdrawUsdc(
        address indexed _user,
        uint256 _amount,
        uint256 _newBalance
    );

    /// @notice Evento que se emite cuando se actualiza la direccion del feed de precios Chainlink.
    event UsdcUpdated(address _old_feed, address _new_feed);

    /// @notice Evento que se emite cuando se agrega un token al catalogo.
    event TokenSupported(
        address indexed newTokenAddress,
        address priceFeedAddress,
        uint8 decimals
    );
    event SwapModule_SwapExecuted(address indexed user);

    /// @notice evento que se emite cuando se actualiza el router
    event RouterUpdated(address _old_router,address _new_router);

    /*//////////////////////////////
            Modificadores
    ///////////////////////////////*/

    /**
     * @dev Constructor del contrato
     * @param _bankCap El límite máximo de fondos que el banco puede manejar (en USD)
     * @param _router La dirección del feed de precios Chainlink ETH/USD
     * @param _usdc LA direccion del token usdc
     */
    constructor(
        uint256 _bankCap,
        address _router,
        address _usdc
    ) Ownable(msg.sender) {
        if (_bankCap == 0) revert ConstructorError("_bankCap");
        bankCap = _bankCap;
        i_router = IUniswapV2Router02(_router);
        i_factory = IUniswapV2Factory(i_router.factory());
        WETH = i_router.WETH();
        s_usdc = _usdc;
    }

    /*//////////////////////////////
            Funciones
    ///////////////////////////////*/

    /**
     * @dev Función para depositar ETH en la cuenta del usuario
     */
    function deposit(
        address _tokenAddress,
        uint256 _tokenAmount,
        uint256 minUsdcOut,
        uint256 deadline
    ) external payable nonReentrant {
        if (_tokenAddress == ETH_ADDRESS) {
            if (_tokenAmount != msg.value)
                revert DepositAmountMismatch(
                    msg.sender,
                    msg.value,
                    _tokenAmount
                );
            depositEth(minUsdcOut, deadline);
        }
        if (_tokenAddress == address(s_usdc)) 
            depositUsdc(_tokenAmount);
        if (_tokenAddress != ETH_ADDRESS && _tokenAddress != address(s_usdc))
            depositToken(_tokenAddress, _tokenAmount, minUsdcOut, deadline);
    }

    /// @notice Deposits USDC directly into the bank.
    /// @param amountUsdc Amount of USDC to deposit.
    /// @custom:security Non-reentrant, requires approval.
    function depositUsdc(
        uint256 amountUsdc
    ) internal {
        if (amountUsdc == 0) revert ZeroAmount();
        if (totalUsdc + amountUsdc > bankCap) revert BankCapLimitExceeded(bankCap);

        IERC20(s_usdc).safeTransferFrom(msg.sender, address(this), amountUsdc);
        unchecked {
            balanceOfUsdc[msg.sender] += amountUsdc;
            totalUsdc += amountUsdc;
        }
        depositosCount++;

        emit DepositUsdc(msg.sender, amountUsdc);
    }

    function depositEth(
        uint256 minUsdcOut,
        uint256 deadline
    ) internal {
        if (msg.value == 0) revert ZeroAmount();

        uint256 usdcBefore = IERC20(s_usdc).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = s_usdc;

        i_router.swapExactETHForTokens{value: msg.value}(
            minUsdcOut,
            path,
            address(this),
            deadline
        );
        depositosCount++;

        uint256 usdcAfter = IERC20(s_usdc).balanceOf(address(this));
        uint256 received = usdcAfter - usdcBefore;
        // Final cap assertion with the actual output
        if (totalUsdc + received > bankCap) revert BankCapLimitExceeded(bankCap);
        unchecked {
            balanceOfUsdc[msg.sender] += received;
            totalUsdc += received;
        }
        // emit DepositSwapped(msg.sender, address(0), msg.value, received);
        emit DepositSwapped(msg.sender, address(0), msg.value, received);
    }
    /*
    * @notice depositar tokens ERC20 y cambiarlos por USDC via UniswapV2
    * @param _tokenIn token que se quiere depositar
    * @param _amountIn cantidad del token a depositar
    * @param minUsdcOut Minimo aceptable de usdc a recibir
    * @param deadline unix timestamp after which the swap expires
    **/
    function depositToken(
        address _tokenIn,
        uint256 _amountIn,
        uint256 minUsdcOut,
        uint256 deadline
    ) internal {
        if (_tokenIn == address(0)) revert ZeroAddress();
        if (_tokenIn == s_usdc) revert UnsupportedToken(_tokenIn);
        if (_amountIn == 0) revert ZeroAmount();
        if (!hasDirects_usdcPair(_tokenIn)) revert UnsupportedToken(_tokenIn);
        if (totalUsdc + minUsdcOut > bankCap) revert BankCapLimitExceeded(bankCap);

        // Pull tokens in first
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
        // Approve router (reset to 0 first to satisfy some ERC20s)
        IERC20(_tokenIn).forceApprove(address(i_router), 0);
        IERC20(_tokenIn).forceApprove(address(i_router), _amountIn);

        uint256 usdcBefore = IERC20(s_usdc).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = s_usdc;

        i_router.swapExactTokensForTokens(
            _amountIn,
            minUsdcOut,
            path,
            address(this),
            deadline
        );
        depositosCount++;

        uint256 usdcAfter = IERC20(s_usdc).balanceOf(address(this));
        uint256 received = usdcAfter - usdcBefore;
        if (totalUsdc + received > bankCap) revert BankCapLimitExceeded(bankCap);
        unchecked {
            balanceOfUsdc[msg.sender] += received;
            totalUsdc += received;
        }

        // emit DepositSwapped(msg.sender, tokenIn, amountIn, received);
        emit DepositSwapped(msg.sender, _tokenIn, _amountIn, received);
    }

    /// @notice funcion privada para manejar el depósito de ETH en caso de que entre en las funciones fallback
    function depositFallback()
        private
        returns (bool)
    {
        if (msg.value == 0) revert ZeroAmount();

        uint256 usdcBefore = IERC20(s_usdc).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = s_usdc;

        i_router.swapExactETHForTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp + 1 hours
        );

        uint256 usdcAfter = IERC20(s_usdc).balanceOf(address(this));
        uint256 received = usdcAfter - usdcBefore;
        // Final cap assertion with the actual output
        if (totalUsdc + received > bankCap) revert BankCapLimitExceeded(bankCap);
        unchecked {
            balanceOfUsdc[msg.sender] += received;
            totalUsdc += received;
        }
        depositosCount++;
        // emit DepositSwapped(msg.sender, address(0), msg.value, received);
        emit DepositSwapped(msg.sender, address(0), msg.value, received);
        return true;
    }
    /**
     * @notice funcion externa para retirar tokens(ERC-20) o eth de la cuenta del usuario. la funcion se encarga de la conversion.
     * @param _amountUsdc La cantidad a retirar en usdc
     * @dev el usuario no deberia poder retirar mas de su balance de tokens
     * @dev el usuario no deberia poder retirar mas del umbral de retiro por transaccion (withdrawalLimit)
     */
    function withdraw(
        uint256 _amountUsdc
    ) public nonReentrant {
        if (msg.sender == address(0)) revert ZeroAddress();
        if (_amountUsdc == 0)
            revert ZeroAmount();
        uint256 bal = balanceOfUsdc[msg.sender];
        if (bal < _amountUsdc) revert InsufficientUserBalance(_amountUsdc, bal);
        if (_amountUsdc > withdrawLimitUSD) revert WithdrawalLimitExceeded(withdrawLimitUSD,_amountUsdc);
        unchecked {
            balanceOfUsdc[msg.sender] = bal - _amountUsdc;
            totalUsdc -= _amountUsdc;
        }
        withdrawalCount ++;

        IERC20(s_usdc).safeTransfer(msg.sender, _amountUsdc);
        emit WithdrawUsdc(msg.sender, _amountUsdc, balanceOfUsdc[msg.sender]);
    }

    /// @notice Checks whether a given token has a direct USDC pair on Uniswap V2.
    /// @param token Token address to check.
    /// @return bool True if a direct USDC pair exists.
    function hasDirects_usdcPair(address token) public view returns (bool) {
        return i_factory.getPair(token, s_usdc) != ETH_ADDRESS;
    }

    /// @notice Returns remaining USDC capacity until reaching the global cap.
    /// @return _remainingCapacity in USDC units.
    function remainingCapacity() external view returns (uint256 _remainingCapacity) {
        if (totalUsdc >= bankCap) return 0;
        _remainingCapacity = bankCap - totalUsdc;
    }

    /// @notice Updates the Uniswap V2 router address.
    /// @dev Also updates the factory reference to match the new router.
    /// @param _router New router address.
    function setRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert ZeroAddress();
        address old = address(i_router);
        i_router = IUniswapV2Router02(_router);
        i_factory = IUniswapV2Factory(i_router.factory());
        emit RouterUpdated(old, _router);
    }

    /// @notice Updates the USDC token contract address.
    /// @param _usdc New USDC token address.
    function setUsdc(address _usdc) external onlyOwner {
        if (_usdc == address(0)) revert ZeroAddress();
        address old = s_usdc;
        s_usdc = _usdc;
        emit UsdcUpdated(old, _usdc);
    }

    /*///////////////////////////////
            Fallbacks
    ///////////////////////////////*/

    /// @notice Función para aceptar ETH directo (sin datos)
    receive() external payable {
        bool success = depositFallback();
        if (!success) revert ReceiveFallbackDepositError(msg.sender, msg.value);
    }

    /// @notice Fallback para llamadas con datos inesperados
    fallback() external payable {
        bool success = depositFallback();
        if (!success) revert FallbackDepositError(msg.sender, msg.value);
    }
}
