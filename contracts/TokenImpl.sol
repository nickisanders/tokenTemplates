pragma solidity >=0.4.24 <0.5.0;


import "./libs/lifecycle/LockableDestroyable.sol";
import "./libs/math/AdditiveMath.sol";
import "./libs/token/SecurityToken.sol";
import "./libs/compliance/Compliance.sol";
import "./libs/registry/Storage.sol";


contract TokenImpl is SecurityToken, LockableDestroyable {

    // ------------------------------- Variables -------------------------------

    address public issuer;
    bool public issuingFinished = false;
    uint256 internal totalSupplyTokens;
    Compliance public compliance;
    Storage public store;

    // Possible 3rd party integration variables
    string public constant name = "Nicki Token";
    string public constant symbol = "NICKI";
    uint8 public constant decimals = 0;


    // ------------------------------- Modifiers -------------------------------

    modifier onlyIssuer() {
        require(msg.sender == issuer, "Only issuer allowed");
        _;
    }

    modifier canIssue() {
        require(!issuingFinished, "Issuing is already finished");
        _;
    }

    modifier canTransfer(address fromAddress, address toAddress) {
        if(fromAddress == issuer) {
            require(store.accountExists(toAddress), "The to address does not exist");
        }
        else {
            require(compliance.canTransfer(fromAddress, toAddress), "Address cannot transfer");
        }
        _;
    }

    modifier canTransferFrom(address fromAddress, address toAddress) {
        if(msg.sender == owner) {
            require(store.accountExists(toAddress), "The to address does not exist");
        }
        else {
            require(compliance.canTransfer(fromAddress, toAddress), "Address cannot transfer");
        }
        _;
    }


    // -------------------------- Events -------------------------------

    /**
     *  This event is emitted when an address is cancelled and replaced with
     *  a new address.  This happens in the case where a shareholder has
     *  lost access to their original address and needs to have their share
     *  reissued to a new address.  This is the equivalent of issuing replacement
     *  share certificates.
    */
    event IssuerSet(address indexed previousIssuer, address indexed newIssuer);
    event Issue(address indexed to, uint256 amount);
    event IssueFinished();


    // ---------------------------- Getters ----------------------------

    function setCompliance(address newComplianceAddress)
    isUnlocked
    onlyOwner
    external {
        compliance = Compliance(newComplianceAddress);
    }

    function setStorage(address s)
    isUnlocked
    onlyOwner
    external {
        store = Storage(s);
    }

    /**
    * @dev transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    *  The `transfer` function MUST NOT allow transfers to addresses that
    *  have not been verified and added to the contract.
    *  If the `to` address is not currently a shareholder then it MUST become one.
    *  If the transfer will reduce `msg.sender`'s balance to 0 then that address
    *  MUST be removed from the list of shareholders.
    */
    function transfer(address to, uint256 value)
    isUnlocked
    isNotCancelled(to)
    transferCheck(value, msg.sender)
    canTransfer(msg.sender, to)
    public
    returns (bool) {
        balances[msg.sender] = balances[msg.sender].subtract(value);
        balances[to] = balances[to].add(value);

        // Adds the shareholder, if they don't already exist.
        shareholders.append(to);

        // Remove the shareholder if they no longer hold tokens.
        if (balances[msg.sender] == 0) {
            shareholders.remove(msg.sender);
        }

        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     *  The `transferFrom` function MUST NOT allow transfers to addresses that
     *  have not been verified and added to the contract.
     *  If the `to` address is not currently a shareholder then it MUST become one.
     *  If the transfer will reduce `from`'s balance to 0 then that address
     *  MUST be removed from the list of shareholders.
     */
    function transferFrom(address from, address to, uint256 value)
    public
    transferCheck(value, from)
    isNotCancelled(to)
    canTransferFrom(from, to)
    isUnlocked
    returns (bool) {
        if(msg.sender != owner) {
            require(value <= allowed[from][msg.sender], "Value exceeds what is allowed to transfer");
            allowed[from][msg.sender] = allowed[from][msg.sender].subtract(value);
        }

        balances[from] = balances[from].subtract(value);
        balances[to] = balances[to].add(value);

        // Adds the shareholder, if they don't already exist.
        shareholders.append(to);

        // Remove the shareholder if they no longer hold tokens.
        if (balances[msg.sender] == 0) {
            shareholders.remove(from);
        }

        emit Transfer(from, to, value);
        return true;
    }

    function setIssuer(address newIssuer)
    isUnlocked
    onlyOwner
    external {
        issuer = newIssuer;
        emit IssuerSet(issuer, newIssuer);
    }

    /**
     * Tokens will be issued only to the issuer's address
     * @param quantity The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function issueTokens(uint256 quantity)
    isUnlocked
    onlyIssuer
    canIssue
    public
    returns (bool) {
        totalSupplyTokens = totalSupplyTokens.add(quantity);
        balances[msg.sender] = balances[msg.sender].add(quantity);
        shareholders.append(msg.sender);
        emit Issue(msg.sender, quantity);
        return true;
    }

    function finishIssuing()
    isUnlocked
    onlyIssuer
    canIssue
    public
    returns (bool) {
        issuingFinished = true;
        emit IssueFinished();
        return issuingFinished;
    }

}
