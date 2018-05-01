/**
 * @title Onasander Token Contract
 * @author Andrzej Wegrzyn email: info@onasander.com
 * @notice Date: April 22, 2018
 * @notice Location: New Jersey, USA
 * @notice IDE: Remix IDE 
 * @notice Solidity Version: 0.4.23
 * 
 * 
 * @notice This smart contract is written to perform basic crowdfunded token functions.  The main purpose of the contract is to 
 * facilitate the sale of the token to investors for the exchange of ETH.
 * 
 * 
 * @dev Style of coding in this contract resembles "banking" type of coding.  Coding was not geared for performance, but for 
 * integrity of the data.  Multiple checks and asserts are included for the safety of the contract, tokens, investors, 
 * and contract owner.
 * 
 * 
 * @dev Many functions in this contract are designed for the future.  Contract owner can configure the contract through the use
 * of contract properties and perform varies maintenance functions.  Some functions will hopefully never have to be used, and 
 * were built as a 'just in case'. 
 * 
 * 
 * @dev Function style brackets {} used in the comments section are not accidental, and they serve a purpose in Remix IDE only.  
 * They create collapsible regions of code just like in some other IDE editors.  They help to structure the .sol file for readability.  
 */

pragma solidity ^0.4.23;
import "./ERC20.sol";
import "./ApproveAndCallFallBack.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./Pausable.sol";

/** @title Onasander Token Contract */
contract MilkaToken is ERC20, Ownable, Pausable
{   
    using SafeMath for uint256; 

    address private wallet;                         //Contract collection wallet for all the funds from the sale
    address private contractOwner;                  //Holds the value of msg.sender for this contract owner (creater)
    address private emptyAddress = 0x0;             // Used for token minting
    string public constant name = "Milka Token9";   //Token name
    string public constant symbol = "MIKA9";        //Token symbol
    uint8 public constant decimals = 18;            //Token decimals
    uint public totalSupply;                        //Token total supply
    uint private ICOStartDate = 1527811200;         // ICO start datatime  Human time (GMT): Friday, June 1, 2018 12:00:00 AM
    uint private ICOEndDate = 1530403200;           // ICO end datatime  Human time (GMT): Sunday, July 1, 2018 12:00:00 AM
    uint private pricePerETH = 500;                 // price of 1 token per 1 ETH
    uint private bounty = 5;                        // Percentage of bounty program. Initiates with 5%
    bool private isSale = false;                    // Is there an ongoing sale of the token?
    bool private referral = false;                  // Is the referral program enabled?
    uint256 private buyPrice = 200;                 // Fixed Buy Price for the token    
    uint256 private sellPrice = 180;                // Fixed Sell Price for the token
    uint private minETHTrashhold;                   // Holds minimum ETH amount required to transfer your tokens between accounts, used for autorefill
    bool private acceptETH = true;                  // Accept ETH flag
    bool private isAutoRefillEnabled = false;       // Flag if auto refill is enabled for sending ETH to clients who don't have enough to transfer
    bool private isSellingTokensBackEnabled = false;// Flag allowing tokens holders to sell their tokens back to us or not
    bool private approvedPurchasesOnly = true;      // This holds the flag if we allow buyers to buy our tokens only if their accounts are approved (ICO registration)
                                                    // when set to FALSE, anybody can buy
                                                    // when set to TRUE, only ICO registered users can buy
                                                    
    // dictionary of all balances and allowences
    mapping(address => uint256) private balances;
    
    // owners of the accounts approve the transfer of an amount to another account
    mapping(address => mapping (address => uint256)) private allowances;
    
    // mapping with all frozen funds addresses
    mapping(address => bool) private frozenAccounts;
    
    // holds all approved accounts during ICO registration
    mapping(address => bool) private approvedAccounts;
 
    // notifies blockchain clients about the transfer
    event Transfer(address indexed from, address indexed to, uint tokens);
    
    // notifies blockchain clients about the amount burn
    event Burn(address indexed from, uint256 tokens);   
    
    // approval event
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    
    // frozen funds event
    event FrozenFunds(address targetAddress, bool isFrozen);
    
    // tokens minted event
    event TokensMinted(address targetAddress, uint256 tokens);
    
    // account approved
    event AccountApproved(address targetAddress, bool isApproved);
    
    // called during ownership transfered
    event OwnershipTransferred(address indexed from, address indexed to);
    
    // buy event
    event BuyTokens(address buyer, uint tokens);
    
    // tokens sold back
    event SellTokens(address seller, uint tokens);
    
    // take money away
    event TakeMoney(address targetAddress, uint tokens);
    
    // refill event
    event Refill(address targetAddress, uint amount);

    // Contract constructor runs only once.  Here we define the contract owner (our token) and give him the initial balance.
    constructor(address contractWallet, uint256 supply) public
    {
        wallet = contractWallet;
        totalSupply = supply**25;
        contractOwner = msg.sender;             // msg.sender becomes contract owner in the constructor
        balances[contractOwner] = totalSupply;  // give initial full balance to contract owner
        
        emit TokensMinted(contractOwner, totalSupply);
    }   

    /** @dev If approve() function returns true, it will invoke the receiveApproval() function of contract tokenRecipient.
      * Token owner can approve for `spender` to transferFrom(...) `tokens`
      * from the token owner's account. The `spender` contract function
      * receiveApproval(...)` is then executed
      * @param spender Spender address that needs to be approved.
      * @param tokens Amount of tokens that need to be approved for spending.
      * @param data Data for the ApproveAndCallFallBack event.
      * @return success Returns true upon completion.
      */
    function approveAndCall(address spender, uint tokens, bytes data) public onlyAfterICOEnd returns(bool success) 
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is snot valid for this transaction.");
        require(spender != 0x0,"SPENDER 0x0 address is not valid for this transaction.");
        require(tokens > 0, "Token transfer amount must be greater than 0.");
        require(!frozenAccounts[msg.sender], "SENDER account is frozen.  Can not approve for spending.");
        require(!frozenAccounts[spender], "SPENDER account is frozen.  Can not approve for spending.");
        
        // approve
        allowances[msg.sender][spender] = tokens;
        assert(allowances[msg.sender][spender] == tokens);
        
        emit Approval(msg.sender, spender, tokens);
        
        // call
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }
        
    /** @dev Returns balance for a particular account address.
      * @param accountAddress Address of the account we want to check balance of.
      * @return balance Returns account balance.
      */
    function balanceOf(address accountAddress) public constant returns (uint balance)
    {
        return balances[accountAddress];
    }
    
    // Returns remaining allowance for sender of the account approved to transfer of an amount to another account
    function allowance(address sender, address spender) public constant returns (uint remainingAmount)
    {
        return allowances[sender][spender];
    }
    
    // Token transfer function. Please note all token transfer will start after the end of ICO.
    function transfer(address to, uint tokens) public onlyAfterICOEnd returns (bool success)
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(to != 0x0,"TO 0x0 address is not valid for this transaction.");
        require(tokens > 0, "Token transfer amount must be greater than 0.");
        require(balances[msg.sender] >= tokens,"SENDER does not have enough tokens.");
        require(balances[to] + tokens > balances[to], "Overflow is not allowed.");
        require(!frozenAccounts[msg.sender], "Account is frozen.  Can not trasfer.");
        uint previousBalances = balances[msg.sender] + balances[to];    // for assertion
        
        // AutoRefill in case client does not have enough ETH to pay for the transfer
        // here we can not really check if the autorefill worked as it depends on many things.  
        // in order for autorefill to work selling back tokens to contract owner must also be enabled
        if(isAutoRefillEnabled && msg.sender.balance < minETHTrashhold) {RunRefill();}
        
        // actual transfer
        balances[msg.sender] -= tokens;
        balances[to] += tokens;
        
        assert(balances[msg.sender] + balances[to] == previousBalances);
        emit Transfer(msg.sender, to, tokens);
        
        return true;
    }
    
    // This function will be used to transfer tokens from one address to another.
    // Send `tokens` amount of tokens from address `from` to address `to`
    // The transferFrom method is used for a withdraw workflow, allowing contracts to send
    // tokens on your behalf, for example to "deposit" to a contract address and/or to charge
    // fees in sub-currencies; the command should fail unless the _from account has
    // deliberately authorized the sender of the message via some mechanism; we propose
    // these standardized APIs for approval:
    function transferFrom(address from, address to, uint tokens) public onlyAfterICOEnd returns(bool success) 
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(from != 0x0,"FROM 0x0 address is not valid for this transaction.");
        require(to != 0x0,"TO 0x0 address is not valid for this transaction.");
        require(tokens > 0, "Token transfer amount must be greater than 0.");
        require(balances[from] >= tokens,"FROM does not have enough tokens.");
        require(allowances[from][msg.sender] >= tokens,"SENDER is not allowed to send more tokens."); // allowance check
        require(balances[to] + tokens > balances[to], "TO overflow is not allowed.");
        require(!frozenAccounts[msg.sender], "SENDER account is frozen.  Can not trasfer.");
        require(!frozenAccounts[from], "FROM account is frozen.  Can not trasfer.");
        uint previousBalances = balances[from] + balances[to];  // assert balances down the line
        uint previousAllowance = allowances[from][msg.sender];  // assert allowance down the line
        
        // AutoRefill in case client does not have enough ETH to pay for the transfer
        // here we can not really check if the autorefill worked as it depends on many things.  
        // in order for autorefill to work selling back tokens to contract owner must also be enabled
        if(isAutoRefillEnabled && msg.sender.balance < minETHTrashhold) {RunRefill();}
        
        // actual transfer
        balances[from] -= tokens;
        allowances[from][msg.sender] -= tokens; // lower the allowance by the amount of tokens 
        balances[to] += tokens;
        
        assert(balances[from] + balances[to] == previousBalances);
        assert(previousAllowance > allowances[from][msg.sender]);
        assert(previousAllowance == allowances[from][msg.sender] + tokens);
        emit Transfer(from, to, tokens);
        
        return true;
    }
    
    // Allow `spender` to withdraw from your account, multiple times, up to the `tokens` amount.
    // If this function is called again it overwrites the current allowance with _value.
    // This function is just being used to make an entry to the allowance array when another contract want to spend some tokens. 
    //_ spender is the address of the contract which is going to use it.
    //_value denotes the number of tokens to be spend.
    // we assume that we can approve for any amount at this point and we check the balances in the transfer process
    function approve(address spender, uint tokens) public onlyAfterICOEnd returns(bool success) 
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(spender != 0x0,"SPENDER 0x0 address is not valid for this transaction.");
        require(tokens > 0, "Token transfer amount must be greater than 0.");
        require(tokens <= totalSupply, "Token transfer amount can not be greater than total token supply.");
        require(tokens <= balances[msg.sender], "Token transfer amount can not be greater than what the sender has in the account.");
        require(!frozenAccounts[msg.sender], "SENDER account is frozen.  Can not approve for spending.");
        require(!frozenAccounts[spender], "SPENDER account is frozen.  Can not approve for spending.");
        
        allowances[msg.sender][spender] = tokens;
        assert(allowances[msg.sender][spender] == tokens);
        
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    // Destory Tokens.  We will have to figure out if we allow users to burn their own coins.  Also, frozen accounts can not
    // burn their own coins.
    function burn(uint256 tokens) public onlyAfterICOEnd returns(bool success) 
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(tokens > 0, "Token burn amount must be greater than 0.");
        require(balances[msg.sender] >= tokens,"SENDER does not have enough tokens.");
        require(totalSupply >= tokens,"Total Token Supply does not have enough tokens.");  // should be true as above line
        require(!frozenAccounts[msg.sender], "SENDER account is frozen.  Can not burn coins.");
        uint previousBalance = balances[msg.sender];  // assert balances down the line
        uint previousTotalSupply = totalSupply;  // assert total supply down the line
        
        // update balance
        balances[msg.sender] -= tokens;
        assert(previousBalance > balances[msg.sender]);
        
        // burn
        totalSupply -= tokens;
        assert(previousTotalSupply > totalSupply);
        assert(previousTotalSupply - totalSupply == previousBalance - balances[msg.sender]);
        
        emit Burn(msg.sender, tokens);
        return true;
    }
    
    // Contract owner has the only right to run this function and destory(burn) someone elses tokens.
    // Contract owner does not need any allowance for this.
    function burnFrom(address from, uint256 tokens) onlyOwner public returns(bool success) 
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(from != 0x0,"FROM 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can burn someone's tokens.");
        require(tokens > 0, "Token burn amount must be greater than 0.");
        require(balances[from] >= tokens,"FROM does not have enough tokens.");
        require(totalSupply >= tokens,"Total Token Supply does not have enough tokens.");  // should be true as above line
        
        uint previousBalance = balances[from];  // assert balances down the line
        uint previousTotalSupply = totalSupply;  // assert total supply down the line
        
        // burn from
        balances[from] -= tokens;
        assert(previousBalance > balances[from]);
        assert(previousBalance - tokens == balances[from]);
        
        // burn total
        totalSupply -= tokens;
        assert(previousTotalSupply > totalSupply);
        assert(previousTotalSupply - totalSupply == previousBalance - balances[from]);
        
        emit Burn(from, tokens);
        return true;
    }

    // Here we mint more tokens if we have to. The tokens get minted into contract owner balance
    function mintTokens(uint256 tokens) onlyOwner public returns (bool sucess)
    {
        require(tokens > 0, "Token amount must be greater than 0.");
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can mint tokens.");
        require(totalSupply > totalSupply + tokens, "There must be more tokens after minting.");
        
        uint previousBalance = balances[contractOwner];  // assert balances down the line
        uint previousTotalSupply = totalSupply;          // assert total supply down the line
        
        // minting
        totalSupply += tokens;
        balances[contractOwner] += tokens;
        
        assert(totalSupply > previousTotalSupply);
        assert(totalSupply == previousTotalSupply + tokens);
        assert(balances[contractOwner] > previousBalance);
        assert(balances[contractOwner] == previousBalance + tokens);
        assert(balances[contractOwner] - previousBalance == totalSupply - previousTotalSupply);
        
        emit TokensMinted(contractOwner, tokens);
        emit Transfer(emptyAddress, contractOwner, tokens);
        return true;
    }
    
    // Here we mint more tokens into someone's account.  Only contract owner can run this function.
    function mintTokensTo(uint256 tokens, address targetAddress) onlyOwner public returns (bool sucess)
    {
        require(tokens > 0, "Token amount must be greater than 0.");
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can mint tokens.");
        require(targetAddress != 0x0,"TARGET ADDRESS 0x0 is not valid for this transaction.");
        require(totalSupply > totalSupply + tokens, "There must be more tokens after minting.");
        
        uint previousBalance = balances[targetAddress];             // assert balances down the line
        uint previousTotalSupply = totalSupply;          // assert total supply down the line
        
        // minting
        totalSupply += tokens;
        balances[targetAddress] += tokens;
        
        assert(totalSupply > previousTotalSupply);
        assert(totalSupply == previousTotalSupply + tokens);
        assert(balances[targetAddress] > previousBalance);
        assert(balances[targetAddress] == previousBalance + tokens);
        assert(balances[targetAddress] - previousBalance == totalSupply - previousTotalSupply);
        
        emit TokensMinted(targetAddress, tokens);
        emit Transfer(emptyAddress, targetAddress, tokens);
        return true;
    }

    // This freezes funds for a given account.  
    function freezeAccount(address targetAddress, bool isFrozen) onlyOwner private
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can freez accounts.");
        require(targetAddress != 0x0,"TARGET ADDRESS 0x0 is not valid for this transaction.");
        
        // freeze funds
        frozenAccounts[targetAddress] = isFrozen;
        emit FrozenFunds(targetAddress, isFrozen);
        
        assert(frozenAccounts[targetAddress] == isFrozen);
    }
    
    // Takes money away from frozen account
    function takeAllMoneyFromFrozenAccount(address targetAddress, uint tokens) onlyOwner private
    {
        require(tokens > 0,"Token value must be at more than 0.");
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can take money from frozen accounts.");
        require(targetAddress != 0x0,"TARGET ADDRESS 0x0 is not valid for this transaction.");
        require(frozenAccounts[targetAddress],"TARGET ADDRESS is not a frozen account.");
        
        uint previousFrozenBalance = balances[targetAddress];
        uint previousContractOwnerBalance = balances[contractOwner];
        
        // take funds
        balances[targetAddress] -= tokens;
        balances[contractOwner] += tokens;
        
        assert(balances[targetAddress] == 0);
        assert(balances[contractOwner] > previousContractOwnerBalance);
        assert(previousFrozenBalance > balances[targetAddress]);
        assert(balances[contractOwner] - previousContractOwnerBalance == previousFrozenBalance - balances[targetAddress]);
        assert(balances[contractOwner] - previousContractOwnerBalance == tokens);
        assert(previousFrozenBalance - balances[targetAddress] == tokens);
        
        emit TakeMoney(targetAddress, previousFrozenBalance);
        emit Transfer(targetAddress, contractOwner, tokens);
    }

    // Approves an account for purchase of our tokens.  This function will run during ICO registration.
    // Every registered ICO user will be approved here.
    function approveAccountPurchase(address targetAddress, bool isApproved) onlyOwner public
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can mint tokens.");
        require(targetAddress != 0x0,"TARGET ADDRESS 0x0 is not valid for this transaction.");
        
        approvedAccounts[targetAddress] = isApproved;
        emit AccountApproved(targetAddress, isApproved);
    }
    
    // @return true if crowdsale event has ended
    function hasICOEnded() public constant returns (bool) 
    {
        return now > ICOEndDate;
    }
    
    // send ether to the fund collection wallet
    // override to create custom fund forwarding mechanisms
    function forwardFunds() internal 
    {
        wallet.transfer(msg.value);
    }
    
    // Sets buy and sell prices. 
    function setPrices(uint256 newBuyPrice, uint256 newSellPrice) onlyOwner internal
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can mint tokens.");
        require(newBuyPrice > 0, "BUY Price must be greater than 0.");
        require(newSellPrice > 0, "SELL Price must be greater than 0.");
        
        // set prices
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
        
        assert(newSellPrice + newBuyPrice > 0);
    }
    
    // Automatic buy.  Here we assume buyer is approved and his account is not frozen. We also assume we accept ETH.
    // One Ether is 1000000000000000000 wei. So when setting prices for your token in Ether, add 18 zeros at the end.
    // The contract can hold both its own tokens and Ether
    // Accept ETH flag checks if we can accept ETH or not.
    function buy() payable public onlyAfterICOStart returns (uint tokens)
    {
        if (!acceptETH) {revert();} // Don't accept ETH
        require(msg.value > 0,"VALUE must be greater than 0.");
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(buyPrice > 0, "BUY Price must be greater than 0.");
        require(!frozenAccounts[msg.sender], "Account is frozen.  Can not buy.");
        require(acceptETH, "ETH is not accepted at the moment.");
        
        if (approvedPurchasesOnly)  // otherwise allow everyone to buy
        {
            require(approvedAccounts[msg.sender], "Account is not approved.  Can not buy.");
        }
        
        // calculate amount
        tokens = msg.value/buyPrice;
        assert(msg.value == tokens * buyPrice);
        require(balances[contractOwner] >= tokens, "Contract Balance is less than what you are trying to buy.");
        
        // for assertion
        uint previousBuyerBalance = balances[msg.sender];
        uint previousOwnerBalance = balances[contractOwner];
        
        // buy
        balances[msg.sender] += tokens;
        balances[contractOwner] -= tokens;
        
        // assert everything
        assert(previousBuyerBalance < balances[msg.sender]);
        assert(previousOwnerBalance > balances[contractOwner]);
        assert(balances[msg.sender] - previousBuyerBalance == previousOwnerBalance - balances[contractOwner]);
        assert(tokens == balances[msg.sender] - previousBuyerBalance);
        assert(tokens == previousOwnerBalance - balances[contractOwner]);
        assert(msg.value/buyPrice == balances[msg.sender] - previousBuyerBalance);
        assert(msg.value/buyPrice == previousOwnerBalance - balances[contractOwner]);
        
        emit BuyTokens(msg.sender, tokens);
        emit Transfer(contractOwner, msg.sender, tokens);
        
        return tokens;
    }
    
    // Automatic sell.  Here we assume seller's account is not frozen. We also assume sellprice can be 0.
    // When creating the contract, send enough Ether to it so that it can buy back all the tokens on the market otherwise your contract will 
    // be insolvent and your users won't be able to sell their tokens.
    function sell(uint tokens) public onlyAfterICOEnd returns (uint revenue)
    {
        require(isSellingTokensBackEnabled, "Selling back tokens to Contract Owner is not enabled at the moment.");
        require(tokens > 0,"TOKEN amount for sell must be greater than 0.");
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(balances[msg.sender] >= tokens, "Seller Balance is less than what you are trying to sell.");
        require(!frozenAccounts[msg.sender], "Account is frozen.  Can not sell.");
        
        // calculate revenue 
        revenue = tokens * sellPrice;
        assert(tokens == revenue/sellPrice);
        
        uint previousOwnerBalance = balances[contractOwner];
        uint previousSellerBalance = balances[msg.sender];
        
        // update balances
        balances[contractOwner] += tokens;
        balances[msg.sender] -= tokens;
        
        // assert everything
        assert(previousSellerBalance > balances[msg.sender]);
        assert(previousOwnerBalance < balances[contractOwner]);
        assert(previousSellerBalance - balances[msg.sender] == balances[contractOwner] - previousOwnerBalance);
        assert(tokens == previousSellerBalance - balances[msg.sender]);
        assert(tokens == balances[contractOwner] - previousOwnerBalance);
        assert((revenue / sellPrice) == balances[msg.sender] - previousSellerBalance);
        assert((revenue / sellPrice) == previousOwnerBalance - balances[contractOwner]);
        
        // send revenue back as ETH to seller
        msg.sender.transfer(revenue);   // sends ETH to seller, this must be run at the end to prevent recursion attacks
        
        emit SellTokens(msg.sender, tokens);
        emit Transfer(msg.sender, contractOwner, tokens);
        
        return revenue;
    }
    
    // Fallback function. Used for buying tokens from contract owner by simply sending Ethers to contract.
    function() public onlyAfterICOStart payable 
    {
        // we buy tokens using whatever ETH was sent in
        buy();
    }

    // Sets minimum ETH Balance trashhold for auto refill
    function setMinETHBalance(uint minBalanceInFinney) internal onlyOwner
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can set minimum ETH Balance Trashhold for autorefill.");
        
        minETHTrashhold = minBalanceInFinney * 1 finney;
    }
    
    // This enables the AutoRefill flag.
    // Everytime, you make a transaction on Ethereum you need to pay a fee to the miner of the block that will calculate the result of your
    // smart contract. While this might change in the future, for the moment fees can only be paid in Ether and therefore all users of your 
    // tokens need it. Tokens in accounts with a balance smaller than the fee are stuck until the owner can pay for the necessary fee. 
    // But in some use cases, you might not want your users to think about Ethereum, blockchain or how to obtain Ether, so one possible 
    // approach would have your coin automatically refill the user balance as soon as it detects the balance is dangerously low.
    // This should be disabled by default as it will takes peoples tokens, sells them to us, and gives them enough ETH to transfer.
    // Nice feature, but it dictates something to the token owners, they may not want.
    // AutoRefill is dependant on isSellingTokensBackEnabled being true as we autorefill sells tokens back to us.
    function enableAutoRefill(bool isEnabled) internal onlyOwner
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can enable auto refill.");
        
        isAutoRefillEnabled = isEnabled;
    }
    
    // Performs ETH Auto Refill
    function RunRefill() private onlyAfterICOEnd
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender.balance < minETHTrashhold, "SENDER Balance is more or equal to minimum ETH Trashhold already.");
        require(isAutoRefillEnabled,"Auto Refill is not enabled.");
        require(isSellingTokensBackEnabled,"Selling of tokens back to owner is not enabled at the moment.  Required by autorefill.");
        require(balances[msg.sender] > 0,"SENDER does not have any tokens.");
        
        uint preSenderTokenBalance = balances[msg.sender];
        uint preOwnerTokenBalance = balances[contractOwner];
        uint preSenderETHBalance = msg.sender.balance;
        uint preOwnerETHBalance = contractOwner.balance;
        
        // calculate how many tokens we need to sell in order to meet the minimum ETH Trashhold
        uint ETHMising = minETHTrashhold - msg.sender.balance;
        uint tokensToSell = ETHMising / sellPrice;
        assert(tokensToSell * sellPrice == minETHTrashhold - msg.sender.balance);
        
        require(tokensToSell > 0, "Tokens to Sell for AutoRefill must be greater than 0.");
        require(balances[msg.sender] > tokensToSell,"SENDER does not have enough tokens to sell.");
        
        // sell tokens in order to get ETH
        sell(tokensToSell);
        
        assert(preSenderTokenBalance > balances[msg.sender]);
        assert(preOwnerTokenBalance < balances[contractOwner]);
        assert(preSenderETHBalance < msg.sender.balance);
        assert(preOwnerETHBalance > contractOwner.balance);
        assert(msg.sender.balance >= minETHTrashhold);
        assert(msg.sender.balance - preSenderETHBalance == ETHMising);
        assert(preSenderTokenBalance - balances[msg.sender] == tokensToSell);
        assert(balances[contractOwner] - preOwnerTokenBalance == tokensToSell);
        
        emit Refill(msg.sender, ETHMising);
    }
    
    // Functions with this modifier will be able to run only after the ICO ends. 
    modifier onlyAfterICOEnd
    {
        require(now > ICOEndDate, "Not able to execute any function before the end of ICO.");
        _;
    }
    
    // Functions with this modifier will be able to run only after the ICO starts. 
    modifier onlyAfterICOStart
    {
        require(now > ICOStartDate, "Not able to execute any function before the start of the ICO.");
        _;
    }
    
    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnershipandBalance(address newOwner) internal onlyOwner
    {
        require(msg.sender == contractOwner, "Only contract owner can transfer ownership to someone else.");
        require(balances[contractOwner] + balances[newOwner] < balances[newOwner], "Balances overflow is not allowed.");        
        uint256 preOwnerBalance = balances[contractOwner];
                
        // transfer balance 
        balances[newOwner] += preOwnerBalance;
        balances[contractOwner] -= preOwnerBalance;
        
        assert(preOwnerBalance > balances[contractOwner]);
        assert(balances[contractOwner] == 0);
        assert(balances[newOwner] >= preOwnerBalance);
        
        // tranfer ownership
        super.transferOwnership(newOwner);
        emit Transfer(contractOwner, newOwner, preOwnerBalance);        
    }
    
    // Contract Owner can transfer out any accidentally sent ERC20 tokens
    function transferAnyERC20Token(address tokenAddress, uint tokens) internal onlyOwner returns (bool success)
    {
        require(msg.sender != 0x0,"SENDER 0x0 address is not valid for this transaction.");
        require(msg.sender == contractOwner, "Only contract owner can mint tokens.");
        require(tokenAddress != 0x0,"TOKEN ADDRESS 0x0 is not valid for this transaction.");
        require(tokens > 0, "Tokens must be greater than 0.");
        
        return ERC20(tokenAddress).transfer(contractOwner, tokens);
    }
}