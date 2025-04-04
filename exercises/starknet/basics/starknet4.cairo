// Liz, a friend of Jill, wants to manage inventory for her store on-chain.
// This is a bit challenging for Joe and Jill, Liz prepared an outline
// for how contract should work, can you help Jill and Joe write it?

use starknet::ContractAddress;

#[starknet::interface]
trait ILizInventory<TContractState> {
    fn add_stock(ref self: TContractState, product: felt252, new_stock: u32);
    fn purchase(ref self: TContractState, product: felt252, quantity: u32);
    fn get_stock(self: @TContractState, product: felt252) -> u32;
    fn get_owner(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod LizInventory {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};

    #[storage]
    struct Storage {
        contract_owner: ContractAddress,
        inventory: Map<felt252, u32>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.contract_owner.write(owner);
    }

    #[abi(embed_v0)]
    impl LizInventoryImpl of super::ILizInventory<ContractState> {
        fn add_stock(ref self: ContractState, product: felt252, new_stock: u32) {
            // Check that only the owner can call this function
            let caller = get_caller_address();
            assert(caller == self.contract_owner.read(), 'Only owner can add stock');
            
            // Get current stock and add the new stock
            let current_stock = self.inventory.read(product);
            self.inventory.write(product, current_stock + new_stock);
        }

        fn purchase(ref self: ContractState, product: felt252, quantity: u32) {
            // Get current stock
            let current_stock = self.inventory.read(product);
            
            // Check that there's enough stock available
            assert(current_stock >= quantity, 'Not enough stock available');
            
            // Subtract the purchased quantity from stock
            self.inventory.write(product, current_stock - quantity);
        }

        fn get_stock(self: @ContractState, product: felt252) -> u32 {
            // Return the current stock for the given product
            self.inventory.read(product)
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.contract_owner.read()
        }
    }
}

#[cfg(test)]
mod test {
    use starknet::ContractAddress;
    use starknet::syscalls::deploy_syscall;
    use super::LizInventory;
    use super::ILizInventoryDispatcher;
    use super::ILizInventoryDispatcherTrait;

    #[test]
    #[available_gas(2000000000)]
    fn test_owner() {
        let owner: ContractAddress = 'Elizabeth'.try_into().unwrap();
        let dispatcher = deploy_contract();

        // Check that contract owner is set
        let contract_owner = dispatcher.get_owner();
        assert(contract_owner == owner, 'Elizabeth should be the owner');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_stock() {
        let dispatcher = deploy_contract();
        let owner = util_felt_addr('Elizabeth');

        // Call contract as owner
        starknet::testing::set_contract_address(owner);

        // Add stock
        dispatcher.add_stock('Nano', 10);
        let stock = dispatcher.get_stock('Nano');
        assert(stock == 10, 'stock should be 10');

        dispatcher.add_stock('Nano', 15);
        let stock = dispatcher.get_stock('Nano');
        assert(stock == 25, 'stock should be 25');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_stock_purchase() {
        let owner = util_felt_addr('Elizabeth');
        let dispatcher = deploy_contract();
        // Call contract as owner
        starknet::testing::set_contract_address(owner);

        // Add stock
        dispatcher.add_stock('Nano', 10);
        let stock = dispatcher.get_stock('Nano');
        assert(stock == 10, 'stock should be 10');

        // Call contract as owner
        starknet::testing::set_caller_address(0.try_into().unwrap());

        dispatcher.purchase('Nano', 2);
        let stock = dispatcher.get_stock('Nano');
        assert(stock == 8, 'stock should be 8');
    }

    #[test]
    #[should_panic]
    #[available_gas(2000000000)]
    fn test_set_stock_fail() {
        let dispatcher = deploy_contract();
        // Try to add stock, should panic to pass test!
        dispatcher.add_stock('Nano', 20);
    }

    #[test]
    #[should_panic]
    #[available_gas(2000000000)]
    fn test_purchase_out_of_stock() {
        let dispatcher = deploy_contract();
        // Purchse out of stock
        dispatcher.purchase('Nano', 2);
    }

    fn util_felt_addr(addr_felt: felt252) -> ContractAddress {
        addr_felt.try_into().unwrap()
    }

    fn deploy_contract() -> ILizInventoryDispatcher {
        let owner: felt252 = 'Elizabeth';
        let mut calldata = ArrayTrait::new();
        calldata.append(owner);
        let (address0, _) = deploy_syscall(
            LizInventory::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        let contract0 = ILizInventoryDispatcher { contract_address: address0 };
        contract0
    }
}