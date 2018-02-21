pragma solidity ^0.4.18;

import "./dependencies/math/SafeMath.sol";
import "./dependencies/ownership/Ownable.sol";
import "./dependencies/token/ERC20/TokenVesting.sol";
import "./SimpleTGE.sol";
import "./SimplePreTGE.sol";
import "./LendroidSupportToken.sol";

/**
 * @title SimpleLSTDistribution
 * @dev SimpleLSTDistribution contract provides interface for the contributor to withdraw their allocations / initiate the vesting contract
 */
contract SimpleLSTDistribution is Ownable {
  using SafeMath for uint256;

  SimplePreTGE public SimplePreTGEContract;
  SimpleTGE public SimpleTGEContract;
  LendroidSupportToken public token;
  uint256 LSTRatePerWEI;
  //vesting related params
  // bonus multiplied to every vesting contributor's allocation
  uint256 vestingBonusMultiplier;
  uint256 vestingDuration;
  uint256 vestingStartTime;

  struct allocation {
    bool shouldVest;
    uint256 weiContributed;
    uint256 LSTAllocated;
    bool hasWithdrawn;
  }
  // maps all allocations claimed by contributors
  mapping (address => allocation)  public allocations;

  // map of address to token vesting contract
  mapping (address => TokenVesting) public vesting;

  /**
   * event for token transfer logging
   * @param beneficiary who is receiving the tokens
   * @param tokens amount of tokens given to the beneficiary
   */
  event LogLSTsWithdrawn(address beneficiary, uint256 tokens);

  /**
   * event for time vested token transfer logging
   * @param beneficiary who is receiving the time vested tokens
   * @param tokens amount of tokens that will be vested to the beneficiary
   * @param start unix timestamp at which the tokens will start vesting
   * @param cliff duration in seconds after start time at which vesting will start
   * @param duration total duration in seconds in which the tokens will be vested
   */
  event LogTimeVestingLSTsWithdrawn(address beneficiary, uint256 tokens, uint256 start, uint256 cliff, uint256 duration);

  function SimpleLSTDistribution(
      address _SimplePreTGEAddress,
      address _SimpleTGEAddress,
      address _LSTTokenAddress,
      uint256 _vestingBonusMultiplier,
      uint256 _vestingDuration,
      uint256 _vestingStartTime
    ) public {
    SimplePreTGEContract = SimplePreTGE(_SimplePreTGEAddress);
    SimpleTGEContract = SimpleTGE(_SimpleTGEAddress);
    token = LendroidSupportToken(_LSTTokenAddress);
    vestingBonusMultiplier = _vestingBonusMultiplier;
    vestingDuration = _vestingDuration;
    vestingStartTime = _vestingStartTime;
  }

  function withdraw() external {
    require(!allocations[msg.sender].hasWithdrawn);
    // make sure simpleTGE is over and the TRS subscription has ended
    require(block.timestamp > SimpleTGEContract.publicTGEEndBlockTimeStamp().add(SimpleTGEContract.TRSOffset()));
    // allocations should be locked in the pre-TGE
    require(SimplePreTGEContract.allocationsLocked());
    // should have participated in the TGE or the pre-TGE
    bool _preTGEHasVested;
    uint256 _preTGEWeiContributed;
    bool _publicTGEHasVested;
    uint256 _publicTGEWeiContributed;
    (_publicTGEHasVested, _publicTGEWeiContributed) = SimpleTGEContract.contributions(msg.sender);
    (_preTGEHasVested, _preTGEWeiContributed) = SimplePreTGEContract.contributions(msg.sender);
    uint256 _totalWeiContribution = _preTGEWeiContributed.add(_publicTGEWeiContributed);
    require(_totalWeiContribution > 0);
    // the same contributor could have contributed in the pre-tge and the tge, so we add the contributions.
    bool _shouldVest = _preTGEHasVested || _publicTGEHasVested;
    allocations[msg.sender].hasWithdrawn = true;
    allocations[msg.sender].shouldVest = _shouldVest;
    allocations[msg.sender].weiContributed = _totalWeiContribution;
    uint256 _lstAllocated;
    if (!_shouldVest) {
      _lstAllocated = LSTRatePerWEI.mul(_totalWeiContribution);
      allocations[msg.sender].LSTAllocated = _lstAllocated;
      require(token.mint(msg.sender, _lstAllocated));
      LogLSTsWithdrawn(msg.sender, _lstAllocated);
    }
    else {
      _lstAllocated = LSTRatePerWEI.mul(_totalWeiContribution).mul(vestingBonusMultiplier);
      allocations[msg.sender].LSTAllocated = _lstAllocated;
      uint256 _withdrawNow = _lstAllocated.div(10);
      uint256 _vestedPortion = _lstAllocated.sub(_withdrawNow);
      vesting[msg.sender] = new TokenVesting(msg.sender, vestingStartTime, vestingStartTime, vestingDuration, false);
      require(token.mint(msg.sender, _withdrawNow));
      LogLSTsWithdrawn(msg.sender, _withdrawNow);
      require(token.mint(address(vesting[msg.sender]), _vestedPortion));
      LogTimeVestingLSTsWithdrawn(msg.sender, _vestedPortion, vestingStartTime, vestingStartTime, vestingDuration);
    }
  }

  // member function that can be called to release vested tokens periodically
  function releaseVestedTokens(address beneficiary) public {
    require(beneficiary != 0x0);

    TokenVesting tokenVesting = vesting[beneficiary];
    tokenVesting.release(token);
  }

}
