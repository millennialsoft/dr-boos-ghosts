// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

abstract contract Market {
    function isMember(address user) public view virtual returns (bool);
    function addToEscrow(address _address) external virtual payable;
}

abstract contract BrotherHood {
      function walletOfOwner(address _owner) public view virtual returns (uint256[] memory);
}


contract DrBoosGhosts is
ERC721Enumerable,
Ownable
{
    using Strings for uint256;

    string public baseURI;
    string public baseExtension = ".json";

    uint256 public publicCost = 390 ether;
    uint256 public EbisusbayMemberPrice = 340 ether;
    uint256 public whiteListCost = 290 ether;

    //Restrictions

    uint256 public maxSupply = 2111;
    uint256 public reservedNft = 80;


    uint256 public maxMintAmount = 25;
    uint256 public nftPerAddressLimit = 100;
    uint256 public maxNFTforWLUser = 3;
    uint256 public reservedMintedNFT = 0;

    //Ebisusbay FEE : 10%
    uint256 public ebisusbayFee = 10;
    // EbisusbayWallet
    address public ebisusbayWallet = 0x454cfAa623A629CC0b4017aEb85d54C42e91479d;

    //Mainnet
    address public marketAddress =
        0x7a3CdB2364f92369a602CAE81167d0679087e6a3;
            address public BHAddress = 0xd0062DEb460Eac0cB7cE77C312F8aa58378b6d8a;


    bool public paused = false;
    bool public onlyWhitelisted = false;

    struct Infos {
        uint256 regularCost;
        uint256 memberCost;
        uint256 whitelistCost;
        uint256 maxSupply;
        uint256 totalSupply;
        uint256 maxMintPerAddress;
        uint256 maxMintPerTx;
    }

    mapping(address => uint256) public addressMintedBalance;
    mapping(address => bool) public whitelistedAddresses;
    mapping(address => uint256) public whitelistedBalance;

    constructor()
    ERC721('DrBoosGhosts', 'DBG')
    {
        setBaseURI('https://bhfiles.mypinata.cloud/ipfs/QmZ9CiNjFT8EneGxwrwEtBgib5JRDe8FCt5SUut5Mcsh8d/');
    }

    function getInfo() public view returns (Infos memory) {
        Infos memory allInfos;
        allInfos.regularCost = publicCost;
        allInfos.memberCost = EbisusbayMemberPrice;
        allInfos.whitelistCost = whiteListCost;
        allInfos.maxSupply = maxSupply;
        allInfos.totalSupply = totalSupply();
        allInfos.maxMintPerAddress = nftPerAddressLimit;
        allInfos.maxMintPerTx = maxMintAmount;

        return allInfos;
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // Mint Function for White-List and Public Sale
    event MintEvent(address indexed _from, uint256 indexed mintAmount);

    function mint(uint256 _mintAmount) public payable {
        require(!paused, "contract is paused");
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _mintAmount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        require((supply + _mintAmount + reservedNft - reservedMintedNFT) <= maxSupply, "max NFT limit exceeded");

        if (msg.sender != owner()) {
            if (onlyWhitelisted == true) {
                require(verifyUser(msg.sender), "not in whitelisted");
            }

            uint256 ownerMintedCount = addressMintedBalance[msg.sender];
            require(
                (ownerMintedCount + _mintAmount) <= nftPerAddressLimit,
                "max NFT per address exceeded"
            );

            if (verifyUser(msg.sender)) {
                require( (_mintAmount + whitelistedBalance[msg.sender]) <= maxNFTforWLUser, "no credit left");
                require(msg.value >= whiteListCost * _mintAmount, "insufficient funds");

                      for (uint256 i = 1; i <= _mintAmount; i++) {
                    addressMintedBalance[msg.sender]++;
                    whitelistedBalance[msg.sender]++;
                    _safeMint(msg.sender, supply + reservedNft + i - reservedMintedNFT );
                }


            } else {

                uint256 amountFee;

                if (isEbisusBayMember(msg.sender)) {
                    require(
                        msg.value >= (EbisusbayMemberPrice * _mintAmount),
                        "insufficient funds"
                    );
                    amountFee =
                        ((EbisusbayMemberPrice * _mintAmount) * ebisusbayFee) /
                        100;
                } else {

                    require(
                        msg.value >= (publicCost * _mintAmount),
                        "insufficient funds"
                    );
                    amountFee =
                        ((publicCost * _mintAmount) * ebisusbayFee) /
                        100;
             }


                for (uint256 i = 1; i <= _mintAmount; i++) {
                    addressMintedBalance[msg.sender]++;
                  _safeMint(msg.sender, supply + reservedNft + i - reservedMintedNFT );
                }
                 emit MintEvent(msg.sender, _mintAmount);
                  Market market = Market(marketAddress);
                  market.addToEscrow{value : amountFee}(ebisusbayWallet);
            }


        } else {
                require(reservedNft - (reservedMintedNFT + _mintAmount) >= 0, "All Reserved NFT Minted");
                for (uint256 i = 1; i <= _mintAmount; i++) {
                    addressMintedBalance[msg.sender]++;
                   reservedMintedNFT++;
                    _safeMint(msg.sender, reservedMintedNFT);

                }
        }

    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        require(_owner != address(0), "not address 0");
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    // White List

    function setAllowList(address[] calldata addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Invalid address");
            whitelistedAddresses[addresses[i]] = true;
        }
    }

    function verifyUser(address _whitelistedAddress)
        public
        view
        returns (bool)
    {
        require(_whitelistedAddress != address(0), "not address 0");


        
        BrotherHood BH = BrotherHood(BHAddress);
        uint256 BHWallet  = BH.walletOfOwner(_whitelistedAddress).length;

          if(whitelistedAddresses[_whitelistedAddress] || BHWallet > 0 ){
            if(whitelistedBalance[_whitelistedAddress] < maxNFTforWLUser){
                return true;
            }
        }
        
       return false;
    }

    function setOnlyWhitelisted(bool _state) public onlyOwner {
        onlyWhitelisted = _state;
    }

    // End of White List;

    function getBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    // Ebisusbay Member

   function isEbisusBayMember(address _address) public view returns (bool) {
       Market market = Market(marketAddress);
       return market.isMember(_address);
    }

    function setMemberShipAddress(address _address) public onlyOwner {
        marketAddress = _address;
    }

    //Get NFT Cost
    function mintCost(address _address) public view returns (uint256) {
        require(_address != address(0), "not address 0");
        if (verifyUser(_address)) {
            return whiteListCost;
        }

        if (isEbisusBayMember(_address)) {
            return EbisusbayMemberPrice;
        }

        return publicCost;
    }

    //Math

    // Can Mint Function
    
    function canMint(address _address) public view returns(uint256){
           require(_address != address(0), "not address 0");

             uint256 supply = totalSupply();
          require(supply >= 0, "no nft left");

           if(verifyUser(_address)){
               return maxNFTforWLUser - whitelistedBalance[_address];
           }

            uint256 _amount;
            uint256 ownerMintedCount = addressMintedBalance[_address];

            if(maxMintAmount < ( nftPerAddressLimit - ownerMintedCount) ){
                _amount = maxMintAmount;
            } else {
                _amount =  (nftPerAddressLimit - ownerMintedCount);
            }

            uint256 _nftLeft;
            if(maxSupply == supply){
                _nftLeft = 0;
            } else {
                _nftLeft = maxSupply + reservedMintedNFT - (supply + reservedNft) ;
            }

            if(_nftLeft < _amount){
                return _nftLeft;
            } else {
                return _amount;
            }        
    }
}