pragma solidity ^0.4.0;

import "./ERC20.sol";
import "../collections/AddressMap.sol";
import "../ownership/Ownable.sol";
import "../math/AdditiveMath.sol";


contract SecurityToken is ERC20, Ownable {

    using AdditiveMath for uint256;
    using AddressMap for AddressMap.Data;
    AddressMap.Data public shareholders;
    address constant internal ZERO_ADDRESS = address(0);
    uint256 internal totalSupplyTokens;

    mapping(address => address) public cancellations;
    mapping(address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    event VerifiedAddressSuperseded(address indexed original, address indexed replacement, address indexed sender);


    // ------------------------------- Modifiers -------------------------------

    modifier transferCheck(uint256 value, address fromAddr) {
        require(value <= balances[fromAddr], "Quantity is greater than from address balance");
        _;
    }

    modifier isNotCancelled(address addr) {
        require(cancellations[addr] == ZERO_ADDRESS, "Address has been cancelled");
        _;
    }

    function transfer(address to, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);

    /**
     * @return total number of tokens in existence
     */
    function totalSupply()
    external
    view
    returns (uint256) {
        return totalSupplyTokens;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param addr The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address addr)
    external
    view
    returns (uint256) {
        return balances[addr];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param addrOwner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address addrOwner, address spender)
    external
    view
    returns (uint256) {
        return allowed[addrOwner][spender];
    }

    /**
     *  By counting the number of token holders using `holderCount`
     *  you can retrieve the complete list of token holders, one at a time.
     *  It MUST throw if `index >= holderCount()`.
     *  @param index The zero-based index of the holder.
     *  @return the address of the token holder with the given index.
     */
    function holderAt(int256 index)
    external
    view
    returns (address){
        return shareholders.at(index);
    }

    /**
     *  Checks to see if the supplied address is a share holder.
     *  @param addr The address to check.
     *  @return true if the supplied address owns a token.
     */
    function isHolder(address addr)
    external
    view
    returns (bool) {
        return shareholders.exists(addr);
    }

    /**
     *  Checks to see if the supplied address was superseded.
     *  @param addr The address to check.
     *  @return true if the supplied address was superseded by another address.
     */
    function isSuperseded(address addr)
    onlyOwner
    external
    view
    returns (bool) {
        return cancellations[addr] != ZERO_ADDRESS;
    }

    /**
     *  Gets the most recent address, given a superseded one.
     *  Addresses may be superseded multiple times, so this function needs to
     *  follow the chain of addresses until it reaches the final, verified address.
     *  @param addr The superseded address.
     *  @return the verified address that ultimately holds the share.
     */
    function getSuperseded(address addr)
    onlyOwner
    public
    view
    returns (address) {
        require(addr != ZERO_ADDRESS, "Non-zero address required");
        address candidate = cancellations[addr];
        if (candidate == ZERO_ADDRESS) {
            return ZERO_ADDRESS;
        }
        return candidate;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     *
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value)
    external
    returns (bool) {
        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     *  Cancel the original address and reissue the Tokens to the replacement address.
     *
     *  ***It's on the issuer to make sure the replacement address belongs to a verified investor.***
     *
     *  Access to this function MUST be strictly controlled.
     *  The `original` address MUST be removed from the set of verified addresses.
     *  Throw if the `original` address supplied is not a shareholder.
     *  Throw if the replacement address is not a verified address.
     *  This function MUST emit the `VerifiedAddressSuperseded` event.
     *  @param original The address to be superseded. This address MUST NOT be reused.
     *  @param replacement The address  that supersedes the original. This address MUST be verified.
     */
    function cancelAndReissue(address original, address replacement)
    onlyOwner
    isNotCancelled(replacement)
    external {
        // replace the original address in the shareholders mapping
        // and update all the associated mappings
        require(shareholders.exists(original) && !shareholders.exists(replacement), "Original doesn't exist or replacement does");
        shareholders.remove(original);
        shareholders.append(replacement);
        cancellations[original] = replacement;
        balances[replacement] = balances[original];
        balances[original] = 0;
        emit VerifiedAddressSuperseded(original, replacement, msg.sender);
    }
}
