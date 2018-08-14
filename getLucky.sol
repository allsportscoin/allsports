pragma solidity ^0.4.4;

// ERC20-compliant wrapper token for SOC

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 _a, uint256 _b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (_a == 0) {
      return 0;
    }

    uint256 c = _a * _b;
    assert(c / _a == _b);

    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
    // assert(_b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = _a / _b;
    // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
    assert(_b <= _a);
    uint256 c = _a - _b;

    return c;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
    uint256 c = _a + _b;
    assert(c >= _a);

    return c;
  }
}

contract TokenInterface {
    
    using SafeMath for uint256;

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    uint256 public totalSupply;

    function balanceOf(address _owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _amount) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _amount) returns (bool success);
    function approve(address _spender, uint256 _amount) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
}

contract SocInterface {
    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;

    function transfer(address _to, uint256 _value) public {}

}

contract Token is TokenInterface {
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function _transfer(address _to, uint256 _amount) internal returns (bool success) {
        if (balances[msg.sender] >= _amount && _amount > 0) {
            balances[msg.sender] = balances[msg.sender].sub(_amount);
            balances[_to] = balances[_to].add(_amount);
            Transfer(msg.sender, _to, _amount);
            return true;
        } else {
           return false;
        }
    }

    function _transferFrom(address _from,
                           address _to,
                           uint256 _amount) internal returns (bool success) {
        if (balances[_from] >= _amount
            && allowed[_from][msg.sender] >= _amount
            && _amount > 0) {

            balances[_to] = balances[_to].add(_amount);
            balances[msg.sender] = balances[msg.sender].sub(_amount);
            allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
            Transfer(_from, _to, _amount);
            return true;
        } else {
            return false;
        }
    }

    function approve(address _spender, uint256 _amount) returns (bool success) {
        require(_amount >= 0);
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

}

contract DepositSlot {
    address public constant SOC = 0x2d0e95bd4795d7ace0da3c0ff7b706a5970eb9d3;
    address public wrapper;

    modifier onlyWrapper {
        require(msg.sender == wrapper);
        _;
    }

    function DepositSlot(address _wrapper) {
        wrapper = _wrapper;
    }

    function collect() onlyWrapper {
        uint amount = TokenInterface(SOC).balanceOf(this);
        require(amount > 0);
        SocInterface(SOC).transfer(wrapper, amount);
    }
}

contract SocTokenWrapped is Token {
    string public constant standard = "Token 0.1";
    string public constant name = "Soc Token Wrapped";
    string public constant symbol = "WSOC";
    uint8 public constant decimals = 18;     // same as SOC

    address public constant SOC = 0x2d0e95bd4795d7ace0da3c0ff7b706a5970eb9d3;

    mapping (address => address) depositSlots;
    mapping (address => uint256) public currLuckyPool;
    mapping (address => uint256) public preLoopLuckyPool;
    uint256 public constant maxLucky = 100000*1000000000000000000;     // same as SOC

    
    uint256 public currLuckyTokens = 0;
    uint256 public preLoopLuckyTokens = 0; 

    function createPersonalDepositAddress() returns (address depositAddress) {
        if (depositSlots[msg.sender] == 0) {
            depositSlots[msg.sender] = new DepositSlot(this);
        }

        return depositSlots[msg.sender];
    }

    function getPersonalDepositAddress(address depositer) constant returns (address depositAddress) {
        return depositSlots[depositer];
    }
    
    function getPersonalPreLuckyCount() public returns(uint256 count){
        require(preLoopLuckyPool[msg.sender] >= 0);
        count = preLoopLuckyPool[msg.sender];
        return  count;
    }

    function getPersonalCurrLuckyCount() public returns(uint256 count){
        require(currLuckyPool[msg.sender] >= 0);
        count = currLuckyPool[msg.sender];
        return  count;
    }

    function buyLucker(uint256 amount) public {
        require(amount >= 0);
        require(balances[msg.sender] >= amount);
        require(balances[msg.sender].add(amount) >= balances[msg.sender]);
        
        if(maxLucky >= currLuckyTokens.add(amount)){
            autoLucky(amount);
            if(maxLucky == currLuckyTokens){
                sendLucky();
            }
        }else{
            uint256 needAmount = maxLucky.sub(currLuckyTokens);
            uint256 nextLucyAmount = amount.sub(needAmount);
            autoLucky(needAmount);
            
        }
        
    }

    function autoLucky(uint256 _amount) internal {
        currLuckyPool[msg.sender] = currLuckyPool[msg.sender].add(_amount);
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        currLuckyTokens = currLuckyTokens.add(_amount);
    }

    function sendLucky() internal returns(bool result){
        
        return true;
    }
    
    function processDeposit() {
        require(totalSupply >= 0);

        address depositSlot = depositSlots[msg.sender];
        require(depositSlot != 0);

        DepositSlot(depositSlot).collect();
        uint balance = SocInterface(SOC).balanceOf(this);
        require(balance > totalSupply);

        uint freshWSOC = balance - totalSupply;
        totalSupply += freshWSOC;
        balances[msg.sender] += freshWSOC;
        Transfer(address(this), msg.sender, freshWSOC);
    }

    function transfer(address _to,
                      uint256 _amount) returns (bool success) {
        if (_to == address(this)) {
            withdrawSOC(_amount);   // convert back to SOC
            return true;
        } else {
            return _transfer(_to, _amount);     // standard transfer
        }
    }

    function transferFrom(address _from,
                          address _to,
                          uint256 _amount) returns (bool success) {
        require(_to != address(this));
        return _transferFrom(_from, _to, _amount);
    }


    function withdrawSOC(uint amount) internal {
        require(amount > 0);
        require(balances[msg.sender] >= amount);
        require(totalSupply >= amount);

        balances[msg.sender] -= amount;
        totalSupply -= amount;

        SocInterface(SOC).transfer(msg.sender, amount);
        Transfer(msg.sender, address(this), amount);

    }
}
