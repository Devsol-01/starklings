use starknet::ContractAddress;

#[starknet::interface]
trait IOwnable<TContractState> {
    fn owner(self: @TContractState) -> ContractAddress;
    fn set_owner(ref self: TContractState, new_owner: ContractAddress);
}

// CHANGE 1: Use #[starknet::component] attribute instead of simple mod
#[starknet::component]
mod OwnableComponent {
    use starknet::ContractAddress;
    use super::IOwnable;
    
    #[storage]
    struct Storage {
        owner: ContractAddress,
    }
    
    // CHANGE 2: Add Event enum which is required for components
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
    
    #[embeddable_as(Ownable)]
    impl OwnableImpl<
        TContractState, +HasComponent<TContractState>
    > of IOwnable<ComponentState<TContractState>> {
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner.read()
        }
        fn set_owner(ref self: ComponentState<TContractState>, new_owner: ContractAddress) {
            self.owner.write(new_owner);
        }
    }
    
    // CHANGE 3: Add internal implementation that could be useful for other components
    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn assert_only_owner(self: @ComponentState<TContractState>) {
            let caller = starknet::get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Caller is not the owner');
        }
    }
}

#[starknet::contract]
mod OwnableCounter {
    use starknet::ContractAddress;
    use super::OwnableComponent;
    
    // CHANGE 4: Component declaration is now correct
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::Ownable<ContractState>;
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }
    
    #[storage]
    struct Storage {
        counter: u128,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }
    
    // CHANGE 5: Add constructor to initialize owner
    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialize with zero address or deployer address as needed
        let zero_address: ContractAddress = starknet::contract_address_const::<0>();
        self.ownable.owner.write(zero_address);
    }
}

#[cfg(test)]
mod tests {
    use super::OwnableCounter;
    use super::{IOwnableDispatcher, IOwnable, IOwnableDispatcherTrait};
    use starknet::contract_address_const;
    use starknet::syscalls::deploy_syscall;
    // CHANGE 6: Add missing import
    use array::ArrayTrait;
    
    // CHANGE 7: Add test class hash constant
    const TEST_CLASS_HASH: felt252 = 0x123456; // Placeholder - replace with actual hash
    
    #[test]
    #[available_gas(200_000_000)]
    fn test_contract_read() {
        let dispatcher = deploy_contract();
        dispatcher.set_owner(contract_address_const::<0>());
        assert(contract_address_const::<0>() == dispatcher.owner(), 'Some fuck up happened');
    }
    
    #[test]
    #[available_gas(200_000_000)]
    #[should_panic]
    fn test_contract_read_fail() {
        let dispatcher = deploy_contract();
        dispatcher.set_owner(contract_address_const::<1>());
        assert(contract_address_const::<2>() == dispatcher.owner(), 'Some fuck up happened');
    }
    
    // CHANGE 8: Fix deploy_contract function
    fn deploy_contract() -> IOwnableDispatcher {
        let mut calldata = ArrayTrait::new();
        // Fixed typo in deploy_syscall and changed * to _
        let (address0, _) = deploy_syscall(
            OwnableCounter::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        ).unwrap();
        let contract0 = IOwnableDispatcher { contract_address: address0 };
        contract0
    }
}