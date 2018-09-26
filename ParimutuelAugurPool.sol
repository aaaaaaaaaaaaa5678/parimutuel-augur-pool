pragma solidity ^0.4.25;

/**
 * @title SafeMathUint256
 * @dev Uint256 math operations with safety checks that throw on error
 */
library SafeMathUint256 {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a <= b) {
            return a;
        } else {
            return b;
        }
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return a;
        } else {
            return b;
        }
    }

    function getUint256Min() internal pure returns (uint256) {
        return 0;
    }

    function getUint256Max() internal pure returns (uint256) {
        return 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    }

    function isMultipleOf(uint256 a, uint256 b) internal pure returns (bool) {
        return a % b == 0;
    }

    // Float [fixed point] Operations
    function fxpMul(uint256 a, uint256 b, uint256 base) internal pure returns (uint256) {
        return div(mul(a, b), base);
    }

    function fxpDiv(uint256 a, uint256 b, uint256 base) internal pure returns (uint256) {
        return div(mul(a, base), b);
    }
}

contract ERC20Token {
    function balanceOf(address _owner) public constant returns (uint balance);
    function transfer(address _to, uint _value) public returns (bool success);
    function approve(address _spender, uint _value) public returns (bool success);
}

contract Market {
    function getShareToken(uint256 _outcome) public view returns (address);
    function getNumTicks() public view returns (uint256);
    function getNumberOfOutcomes() public view returns (uint256);
    function getEndTime() public view returns (uint256);
}

contract CompleteSets {
    function publicBuyCompleteSets(Market _market, uint256 _amount) external payable returns (bool);
}

contract ParimutuelAugurPool {
    using SafeMathUint256 for uint256;
    
    CompleteSets constant private completeSets = CompleteSets(0x48FCc9d538B9C86bA9D35b3eB0e7f64EE2B4664f); // rinkeby
    address constant private cash = 0x2Da4d465978981BD75BbaC4C9f3bdA10bE0B465c;
    address constant private augur = 0x990B2D2aF7e87cd015A607c3A95d7622c9bBeDe1;
    
    Market public market;
    uint256 public pools_closed_time;
    uint256 public minimum_bet;
    mapping(address => mapping(uint256 => uint256)) public bets;
    mapping(uint256 => uint256) public outcomes;
    uint256 public number_of_complete_sets_purchased;
    
    
    constructor(address market_, uint256 minimum_bet_, uint256 pools_closed_time_) public {
        require(pools_closed_time_ > block.timestamp, "time travel not invented");
        require(pools_closed_time_ <= Market(market_).getEndTime(), "don't want to wait that long");
        require(minimum_bet_ >= Market(market_).getNumTicks(), "whatever");
        
        market = Market(market_);
        pools_closed_time = pools_closed_time_;
        minimum_bet = minimum_bet_;
        
        ERC20Token(cash).approve(augur, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }
    
    function() public {}
    
    function bet(uint256 outcome) public payable {
        require(outcome < market.getNumberOfOutcomes(), "what are you betting on?");
        require(block.timestamp < pools_closed_time, "too late sucker");
        require(msg.value >= minimum_bet, "don't be cheap");
        
        bets[msg.sender][outcome] = bets[msg.sender][outcome].add(msg.value);
        outcomes[outcome] = outcomes[outcome].add(msg.value);
    }
    
    function finalize() public {
        require(block.timestamp >= pools_closed_time, "be patient");
        require(number_of_complete_sets_purchased == 0, "it's a one time only deal");
        
        uint256 number_of_complete_sets_to_buy = address(this).balance.div(market.getNumTicks());
        completeSets.publicBuyCompleteSets.value(address(this).balance)(market, number_of_complete_sets_to_buy);
        
        number_of_complete_sets_purchased = number_of_complete_sets_to_buy;
    }
    
    function claim(uint256 outcome) public {
        require(number_of_complete_sets_purchased > 0, "be patient");
        
        uint256 bettor_stake_in_outcome = bets[msg.sender][outcome];
        uint256 total_stake_in_outcome = outcomes[outcome];
        
        ERC20Token share = ERC20Token(market.getShareToken(outcome));
        
        uint256 shares_that_you_get = bettor_stake_in_outcome.mul(number_of_complete_sets_purchased).div(total_stake_in_outcome);
        bets[msg.sender][outcome] = 0;
        require(share.transfer(msg.sender, shares_that_you_get), "bitch better have my money");
    }
}