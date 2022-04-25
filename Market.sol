// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract NFTMarket is ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;
  Counters.Counter private _itemsSold;

  address payable owner;
  uint256 listingPrice = 0.025 ether;

  constructor() {
    owner = payable(msg.sender);
  }

  struct MarketItem {
    uint itemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
    bool canceled;
  }

  mapping(uint256 => MarketItem) private idToMarketItem;

  event MarketItemCreated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold,
    bool canceled
  );

  event MaketItemSaled (
    uint indexed itemId,
    address buyer,
    uint256 price
  );

  event ChangeItemPrice (
    uint itemId,
    uint256 newPrice
  );

  event CacnelMaketItem (
    uint itemId
  );

  /* Returns the listing price of the contract */
  function getListingPrice() public view returns (uint256) {
    return listingPrice;
  }

  /** 
    * Places an item for sale on the marketplace
    * @param nftContract: contract address of nft
    * @param tokenId: token need sale
    * @param price: price of nft
  */
  function createMarketItem(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) external payable nonReentrant {
    require(price > 0, "Price must be at least 1 wei");
    require(msg.value == listingPrice, "Price must be equal to listing price");
    require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "ERC721: transfer from incorrect owner");

    _itemIds.increment();
    uint256 itemId = _itemIds.current();
  
    idToMarketItem[itemId] =  MarketItem(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),
      payable(address(0)),
      price,
      false,
      false
    );

    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

    emit MarketItemCreated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      false,
      false
    );
  }

  /** 
    * Creates the sale of a marketplace item 
    * Transfers ownership of the item, as well as funds between parties
    * @param itemId: id of market item
  */
  function createMarketSale(
    uint256 itemId
  ) external payable nonReentrant {
    MarketItem memory marketItemData = idToMarketItem[itemId];

    require(msg.value == marketItemData.price, "Please submit the asking price in order to complete the purchase");
    require(marketItemData.seller != msg.sender, "cannot buy from owner of item");
    require(!marketItemData.sold, "item is sold");
    require(!marketItemData.canceled, "item is canceled");

    marketItemData.seller.transfer(msg.value);
    IERC721(marketItemData.nftContract).transferFrom(address(this), msg.sender, marketItemData.tokenId);
    
    idToMarketItem[itemId].owner = payable(msg.sender);
    idToMarketItem[itemId].sold = true;
    _itemsSold.increment();
    payable(owner).transfer(listingPrice);

    emit MaketItemSaled(
      itemId, 
      msg.sender, 
      msg.value
    );
  }
  
  /** 
    * change price of market item
    * @param itemId: id of market item
    * @param newPrice: new price of item
  */
  function changeItemPrice(uint256 itemId, uint256 newPrice) external nonReentrant {
    MarketItem memory marketItemData = idToMarketItem[itemId];
    require(marketItemData.price != newPrice, "New price The new price must not be the same as the old price");
    require(marketItemData.seller == msg.sender, "change price from incorrect owner");
    require(!marketItemData.sold, "item is sold");
    require(!marketItemData.canceled, "item is canceled");

    idToMarketItem[itemId].price = newPrice;
    marketItemData.seller.transfer(listingPrice);

    emit ChangeItemPrice(
      itemId, 
      newPrice
    );
  }

  /** 
    * cancel market item
    * @param itemId: id of market item
  */
  function cancelMaketItem(uint256 itemId) external nonReentrant {
    MarketItem memory marketItemData = idToMarketItem[itemId];
    require(marketItemData.seller == msg.sender, "cancel item from incorrect owner");
    require(!marketItemData.sold, "item is sold");
    require(!marketItemData.canceled, "item is canceled");

    idToMarketItem[itemId].canceled = true;
    IERC721(marketItemData.nftContract).transferFrom(address(this), msg.sender, marketItemData.tokenId);

    emit CacnelMaketItem(itemId);
  }

  /* Returns all unsold market items */
  function fetchMarketItems() public view returns (MarketItem[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
    uint currentIndex = 0;

    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    for (uint i = 0; i < itemCount; i++) {
      if (idToMarketItem[i + 1].owner == address(0)) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns onlyl items that a user has purchased */
  function fetchMyNFTs() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items a user has created */
  function fetchItemsCreated() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        itemCount += 1; 
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }
}