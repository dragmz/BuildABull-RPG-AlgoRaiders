import FungibleToken from 0x9a0766d93b6608b7
import MetadataViews from 0x631e88ae7f1d7c20
import FungibleTokenMetadataViews from 0x9a0766d93b6608b7

pub contract DugeonToken: FungibleToken {
    pub var totalSupply: UFix64
    pub let VaultStoragePath: StoragePath
    pub let VaultPublicPath: PublicPath
    pub let ReceiverPublicPath: PublicPath

    pub event TokensInitialized(initialSupply: UFix64)
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)
    pub event TokensMinted(amount: UFix64)
    pub event TokensBurned(amount: UFix64)
    pub event MinterCreated(allowedAmount: UFix64)
    pub event BurnerCreated()

    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, MetadataViews.Resolver {
      pub var balance: UFix64
      init(balance: UFix64) {
        self.balance = balance
      }

      pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
        self.balance = self.balance - amount
        emit TokensWithdrawn(amount: amount, from: self.owner?.address)
        return <-create Vault(balance: amount)
      }

      pub fun deposit(from: @FungibleToken.Vault) {
        let vault <- from as! @DugeonToken.Vault
        self.balance = self.balance + vault.balance
        emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
        vault.balance = 0.0
        destroy vault
      }

      destroy() {
        if self.balance > 0.0 {
          DugeonToken.totalSupply = DugeonToken.totalSupply - self.balance
        }
      }

      pub fun getViews(): [Type] {
        return [
          Type<FungibleTokenMetadataViews.FTView>(),
          Type<FungibleTokenMetadataViews.FTDisplay>(),
          Type<FungibleTokenMetadataViews.FTVaultData>()
        ]
      }

      pub fun resolveView(_ view: Type): AnyStruct? {
        switch view {
          case Type<FungibleTokenMetadataViews.FTView>():
            return FungibleTokenMetadataViews.FTView(
              ftDisplay: self.resolveView(Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
              ftVaultData: self.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
            )
          case Type<FungibleTokenMetadataViews.FTDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(
              url: "https://svgshare.com/i/vFU.svg"
            ),
            mediaType: "image/svg+xml"
          )
          let medias = MetadataViews.Medias([media])
          return FungibleTokenMetadataViews.FTDisplay(
            name: "DUN Token",
            symbol: "DUN",
            description: "DUN Token is the token for the Dungeon Flow game on the Flow Blockcahin",
            externalURL: MetadataViews.ExternalURL("https://example-ft.onflow.org"),
            logos: medias,
            socials: {
              "twitter": MetadataViews.ExternalURL("https://twitter.com/IntoTheVerse_")
            }
          )
          case Type<FungibleTokenMetadataViews.FTVaultData>():
          return FungibleTokenMetadataViews.FTVaultData(
            storagePath: DugeonToken.VaultStoragePath,
            receiverPath: DugeonToken.ReceiverPublicPath,
            metadataPath: DugeonToken.VaultPublicPath,
            providerPath: /private/exampleTokenVault,
            receiverLinkedType: Type<&DugeonToken.Vault{FungibleToken.Receiver}>(),
            metadataLinkedType: Type<&DugeonToken.Vault{FungibleToken.Balance, MetadataViews.Resolver}>(),
            providerLinkedType: Type<&DugeonToken.Vault{FungibleToken.Provider}>(),
            createEmptyVaultFunction: (fun (): @DugeonToken.Vault {
              return <-DugeonToken.createEmptyVault()
            })
          )
        }
        return nil
      }
    }

    pub fun createEmptyVault(): @Vault {
      return <-create Vault(balance: 0.0)
    }

    pub fun createNewMinter(allowedAmount: UFix64): @Minter {
      emit MinterCreated(allowedAmount: allowedAmount)
      return <-create Minter(allowedAmount: allowedAmount)
    }

    pub fun createNewBurner(): @Burner {
      emit BurnerCreated()
      return <-create Burner()
    }

  pub resource Minter {
    pub let allowedAmount: UFix64;

    pub fun mintTokens(amount: UFix64): @DugeonToken.Vault {
      pre {
        amount > 0.0: "Amount minted must be greater than zero"
      }
      
      var amountToTransfer: UFix64 = amount;
      
      if(DugeonToken.totalSupply + amount > 1000.0){
        amountToTransfer = 1000.0 - DugeonToken.totalSupply;
        DugeonToken.totalSupply = 1000.0
      }
      else {
        DugeonToken.totalSupply = DugeonToken.totalSupply + amount
      }

      emit TokensMinted(amount: amount)
      return <-create Vault(balance: amount)
    }

    init(allowedAmount: UFix64) {
      self.allowedAmount = allowedAmount
    }
  }

  pub resource Burner {
    pub fun burnTokens(from: @FungibleToken.Vault) {
      let vault <- from as! @DugeonToken.Vault
      let amount = vault.balance
      destroy vault
      emit TokensBurned(amount: amount)
    }
  }

  init() {
    self.totalSupply = 0.0
    self.VaultStoragePath = /storage/exampleTokenVault
    self.VaultPublicPath = /public/exampleTokenMetadata
    self.ReceiverPublicPath = /public/exampleTokenReceiver

    emit TokensInitialized(initialSupply: self.totalSupply)
  }
}
