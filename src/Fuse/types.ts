import JumpRateModel from "./irm/JumpRateModel";
import JumpRateModelV2 from "./irm/JumpRateModelV2";
import DAIInterestRateModelV2 from "./irm/DAIInterestRateModelV2";
import WhitePaperInterestRateModel from "./irm/WhitePaperInterestRateModel";
import { BigNumber } from "ethers";

export type MinifiedContracts = {
  [key: string]: {
    abi?: any;
    bin?: any;
  };
};

export type MinifiedCompoundContracts = {
  [key: string]: {
    abi?: any;
    bytecode?: any;
  };
};

export type MinifiedOraclesContractss = MinifiedCompoundContracts;

export type interestRateModelType =
  | JumpRateModel
  | JumpRateModelV2
  | DAIInterestRateModelV2
  | WhitePaperInterestRateModel
  | undefined;

export type cERC20Conf = {
  delegateContractName?: any;
  underlying: string; // underlying ERC20
  comptroller: string; // Address of the comptroller
  interestRateModel: string; // Address of the IRM
  initialExchangeRateMantissa: BigNumber; // Initial exchange rate scaled by 1e18
  name: string; // ERC20 name of this token
  symbol: string; // ERC20 Symbol
  decimals: number; // decimal precision
  admin: string; // Address of the admin
  collateralFactor: number;
  reserveFactor: number;
  adminFee: number;
  bypassPriceFeedCheck: boolean;
};

export type OracleConf = {
  anchorPeriod?: any;
  tokenConfigs?: any;
  canAdminOverwrite?: any;
  isPublic?: any;
  maxSecondsBeforePriceIsStale?: any;
  chainlinkPriceOracle?: any;
  secondaryPriceOracle?: any;
  reporter?: any;
  anchorMantissa?: any;
  isSecure?: any;
  useRootOracle?: any;
  underlyings?: any;
  sushiswap?: any;
  oracles?: any;
  admin?: any;
  rootOracle?: any;
  uniswapV2Factory?: any;
  baseToken?: any;
  uniswapV3Factory?: any;
  feeTier?: any;
  defaultOracle?: any;
};

export type interestRateModelParams = {
  baseRatePerYear?: string;
  multiplierPerYear?: string;
  jumpMultiplierPerYear?: string;
  kink?: string;
};

export type interestRateModelConf = {
  interestRateModel?: any;
  interestRateModelParams?: interestRateModelParams;
};
