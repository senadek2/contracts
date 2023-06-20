// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { ILeveredPositionFactory } from "./ILeveredPositionFactory.sol";
import { LeveredPosition } from "./LeveredPosition.sol";
import { ICErc20 } from "../../compound/CTokenInterfaces.sol";
import { IComptroller } from "../../compound/ComptrollerInterface.sol";
import { BasePriceOracle } from "../../oracles/BasePriceOracle.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract LeveredPositionsLens is Initializable {
  ILeveredPositionFactory public factory;

  function initialize(ILeveredPositionFactory _factory) external initializer {
    factory = _factory;
  }

  /// @notice this is a lens fn, it is not intended to be used on-chain
  /// @dev returns lists of the market addresses, names and symbols of the underlying assets of those collateral markets that are whitelisted
  function getCollateralMarkets()
    external
    view
    returns (
      address[] memory markets,
      IComptroller[] memory poolOfMarket,
      address[] memory underlyings,
      uint256[] memory underlyingPrices,
      string[] memory names,
      string[] memory symbols,
      uint8[] memory decimals,
      uint256[] memory totalUnderlyingSupplied,
      uint256[] memory ratesPerBlock
    )
  {
    markets = factory.getWhitelistedCollateralMarkets();
    poolOfMarket = new IComptroller[](markets.length);
    underlyings = new address[](markets.length);
    underlyingPrices = new uint256[](markets.length);
    names = new string[](markets.length);
    symbols = new string[](markets.length);
    totalUnderlyingSupplied = new uint256[](markets.length);
    decimals = new uint8[](markets.length);
    ratesPerBlock = new uint256[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(markets[i]);
      poolOfMarket[i] = market.comptroller();
      underlyingPrices[i] = BasePriceOracle(poolOfMarket[i].oracle()).getUnderlyingPrice(market);
      underlyings[i] = market.underlying();
      ERC20Upgradeable underlying = ERC20Upgradeable(underlyings[i]);
      names[i] = underlying.name();
      symbols[i] = underlying.symbol();
      decimals[i] = underlying.decimals();
      totalUnderlyingSupplied[i] = market.getTotalUnderlyingSupplied();
      ratesPerBlock[i] = market.supplyRatePerBlock();
    }
  }

  /// @notice this is a lens fn, it is not intended to be used on-chain
  /// @dev returns the Rate for the chosen borrowable at the specified  leverage ratio and supply amount
  function getBorrowRateAtRatio(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    uint256 _baseCollateral,
    uint256 _targetLeverageRatio
  ) external view returns (uint256) {
    IComptroller pool = IComptroller(_stableMarket.comptroller());
    BasePriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(_stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(_collateralMarket);

    uint256 borrowAmount = ((_targetLeverageRatio - 1e18) * _baseCollateral * collateralAssetPrice) /
      (stableAssetPrice * 1e18);
    return _stableMarket.borrowRatePerBlockAfterBorrow(borrowAmount);
  }

  /// @notice this is a lens fn, it is not intended to be used on-chain
  /// @dev returns lists of the market addresses, names, symbols and the current Rate for each Borrowable asset
  function getBorrowableMarketsAndRates(ICErc20 _collateralMarket)
    external
    view
    returns (
      address[] memory markets,
      address[] memory underlyings,
      string[] memory names,
      string[] memory symbols,
      uint256[] memory rates,
      uint8[] memory decimals
    )
  {
    markets = factory.getBorrowableMarketsByCollateral(_collateralMarket);
    underlyings = new address[](markets.length);
    names = new string[](markets.length);
    symbols = new string[](markets.length);
    rates = new uint256[](markets.length);
    decimals = new uint8[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(markets[i]);
      address underlyingAddress = market.underlying();
      underlyings[i] = underlyingAddress;
      ERC20Upgradeable underlying = ERC20Upgradeable(underlyingAddress);
      names[i] = underlying.name();
      symbols[i] = underlying.symbol();
      rates[i] = market.borrowRatePerBlock();
      decimals[i] = underlying.decimals();
    }
  }

  /// @notice this is a lens fn, it is not intended to be used on-chain
  function getNetAPY(
    uint256 _supplyAPY,
    uint256 _supplyAmount,
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    uint256 _targetLeverageRatio
  ) public view returns (int256 netAPY) {
    if (_supplyAPY == 0 || _supplyAmount == 0 || _targetLeverageRatio <= 1e18) return 0;

    IComptroller pool = IComptroller(_collateralMarket.comptroller());
    BasePriceOracle oracle = pool.oracle();
    // TODO the calcs can be implemented without using collateralAssetPrice
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(_collateralMarket);

    // total collateral = base collateral + levered collateral
    uint256 totalCollateral = (_supplyAmount * _targetLeverageRatio) / 1e18;
    uint256 yieldFromTotalSupplyScaled = _supplyAPY * totalCollateral;
    int256 yieldValueScaled = int256((yieldFromTotalSupplyScaled * collateralAssetPrice) / 1e18);

    uint256 borrowedValueScaled = (totalCollateral - _supplyAmount) * collateralAssetPrice;
    uint256 _borrowRate = _stableMarket.borrowRatePerBlock() * factory.blocksPerYear();
    int256 borrowInterestValueScaled = int256((_borrowRate * borrowedValueScaled) / 1e18);

    int256 netValueDiffScaled = yieldValueScaled - borrowInterestValueScaled;

    netAPY = ((netValueDiffScaled / int256(collateralAssetPrice)) * 1e18) / int256(_supplyAmount);
  }

  function getPositionsInfo(LeveredPosition[] calldata positions, uint256[] calldata supplyApys)
    external
    view
    returns (PositionInfo[] memory infos)
  {
    infos = new PositionInfo[](positions.length);
    for (uint256 i = 0; i < positions.length; i++) {
      infos[i] = getPositionInfo(positions[i], supplyApys[i]);
    }
  }

  function getNetApyForPosition(LeveredPosition pos, uint256 _supplyAPY) public view returns (int256) {
    return
      getNetAPY(
        _supplyAPY,
        pos.baseCollateral(),
        pos.collateralMarket(),
        pos.stableMarket(),
        pos.getCurrentLeverageRatio()
      );
  }

  struct PositionInfo {
    uint256 positionSupplyAmount;
    uint256 positionValue;
    uint256 debtValue;
    uint256 equityValue;
    int256 currentApy;
    uint256 debtRatio;
    uint256 liquidationThreshold;
    uint256 safetyBuffer;
  }

  function getPositionInfo(LeveredPosition pos, uint256 supplyApy) public view returns (PositionInfo memory info) {
    ICErc20 collateralMarket = pos.collateralMarket();
    ICErc20 stableMarket = pos.stableMarket();
    IComptroller pool = pos.pool();
    uint256 collateralPrice = pool.oracle().getUnderlyingPrice(collateralMarket);
    {
      info.positionSupplyAmount = collateralMarket.balanceOfUnderlying(address(pos));
      info.positionValue = (collateralPrice * info.positionSupplyAmount) / 1e18;
      info.currentApy = getNetApyForPosition(pos, supplyApy);
    }

    {
      uint256 borrowedPrice = pool.oracle().getUnderlyingPrice(stableMarket);
      info.debtValue = (borrowedPrice * stableMarket.borrowBalanceCurrent(address(pos))) / 1e18;
      info.equityValue = (collateralPrice * pos.baseCollateral()) / 1e18;
      info.debtRatio = (info.debtValue * 1e18) / info.equityValue;
    }

    {
      (, uint256 collateralFactor) = pool.markets(address(collateralMarket));
      uint256 liquidity = (info.positionValue * collateralFactor) / 1e18;
      info.liquidationThreshold = (liquidity * 1e18) / info.equityValue;
      info.safetyBuffer = ((liquidity - info.debtValue) * 1e18) / info.equityValue;
    }
  }
}
