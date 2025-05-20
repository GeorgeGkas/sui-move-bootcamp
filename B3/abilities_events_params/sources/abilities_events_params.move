module abilities_events_params::abilities_events_params;

use std::string::String;
use sui::event;

//Error Codes
const EMedalOfHonorNotAvailable: u64 = 111;

// Structs
public struct HeroMinted has copy, drop {
    hero: ID,
    owner: address,
}

public struct MedalAwarded has copy, drop {
    hero: ID,
    medal: ID,
    owner: address,
}

public struct Medal has key, store {
    id: UID,
    name: String,
}

public struct Hero has key {
    id: UID, // required
    name: String,
     medals: vector<Medal>,
}

public struct HeroRegistry has key, store {
    id: UID,
    heroes: vector<ID>
}

public struct MedalStorage has key {
    id: UID,
    medals: vector<ID>,
}


// Module Initializer
fun init(ctx: &mut TxContext) {
    let registry = HeroRegistry {
        id: object::new(ctx),
        heroes: vector::empty()
    };

     let medalStorage = MedalStorage {
        id: object::new(ctx),
        medals: vector::empty(),
    };

    transfer::share_object(registry);
    transfer::share_object(medalStorage);
}

// public fun mint_hero(name: String, ctx: &mut TxContext): Hero {
public fun mint_hero(name: String, registry: &mut HeroRegistry, ctx: &mut TxContext): Hero {
    let freshHero = Hero {
        id: object::new(ctx), // creates a new UID
        name,
        medals: vector::empty()
    };

    let minted = HeroMinted {
        hero: object::id(&freshHero),
        owner: ctx.sender()
    };

    // https://docs.sui.io/standards/wallet-standard
    registry.heroes.push_back(object::id(&freshHero));
    
    event::emit(minted);

    freshHero
}

// public entry fun mint_and_keep_hero(name: String, ctx: &mut TxContext) {
public entry fun mint_and_keep_hero(name: String, registry: &mut HeroRegistry, ctx: &mut TxContext) {
    let hero = mint_hero(name, registry, ctx);
    // let hero = mint_hero(name, ctx);
    transfer::transfer(hero, ctx.sender());
}

public entry fun award_medal_of_honor(
    hero: &mut Hero,
    medalStorage: &mut MedalStorage,
    medal: Medal,
    ctx: &mut TxContext,
) {
    event::emit(MedalAwarded {
        hero: object::id(hero),
        medal: object::id(&medal),
        owner: ctx.sender(),
    });

    medalStorage.medals.push_back(object::id(&medal));
    hero.medals.push_back(medal);
}


/////// Tests ///////

#[test_only]
use sui::test_scenario as ts;
#[test_only]
use sui::test_scenario::{take_shared, return_shared};
#[test_only]
use sui::test_utils::{destroy, assert_eq};
use std::address;

//--------------------------------------------------------------
//  Test 1: Hero Creation
//--------------------------------------------------------------
//  Objective: Verify the correct creation of a Hero object.
//  Tasks:
//      1. Complete the test by calling the `mint_hero` function with a hero name.
//      2. Assert that the created Hero's name matches the provided name.
//      3. Properly clean up the created Hero object using `destroy`.
//--------------------------------------------------------------
#[test]
fun test_hero_creation() {
    let mut test = ts::begin(@USER);
    init(test.ctx());
    test.next_tx(@USER);

    // Get hero Registry
    let mut heroRegistry = take_shared<HeroRegistry>(&test);

    // Mint hero
    let hero = mint_hero( b"test".to_string(), &mut heroRegistry, test.ctx());

    // Assert hero was created
    assert_eq(hero.name, b"test".to_string());

    destroy(hero);

    return_shared(heroRegistry);

    test.end();
}

//--------------------------------------------------------------
//  Test 2: Event Emission
//--------------------------------------------------------------
//  Objective: Implement event emission during hero creation and verify its correctness.
//  Tasks:
//      1. Define a `HeroMinted` event struct with appropriate fields (e.g., hero ID, owner address).  Remember to add `copy, drop` abilities!
//      2. Emit the `HeroMinted` event within the `mint_hero` function after creating the Hero.
//      3. In this test, capture emitted events using `event::events_by_type<HeroMinted>()`.
//      4. Assert that the number of emitted `HeroMinted` events is 1.
//      5. Assert that the `owner` field of the emitted event matches the expected address (e.g., @USER).
//--------------------------------------------------------------
#[test]
fun test_event_thrown() { 
    let mut test = ts::begin(@USER);
    init(test.ctx());
    test.next_tx(@USER);

    let mut heroRegistry = take_shared<HeroRegistry>(&test);
    let hero = mint_hero(b"test".to_string(), &mut heroRegistry,  test.ctx());

    let events = event::events_by_type<HeroMinted>();

    assert_eq(events.length(), 1); 
    assert_eq(events[0].owner, @USER);

    destroy(hero);
    return_shared(heroRegistry);
    test.end();
}



//--------------------------------------------------------------
//  Test 3: Medal Awarding
//--------------------------------------------------------------
//  Objective: Implement medal awarding functionality to heroes and verify its effects.
//  Tasks:
//      1. Define a `Medal` struct with appropriate fields (e.g., medal ID, medal name). Remember to add `key, store` abilities!
//      2. Add a `medals: vector<Medal>` field to the `Hero` struct to store the medals a hero has earned.
//      3. Create functions to award medals to heroes, e.g., `award_medal_of_honor(hero: &mut Hero)`.
//      4. In this test, mint a hero.
//      5. Award a specific medal (e.g., Medal of Honor) to the hero using your `award_medal_of_honor` function.
//      6. Assert that the hero's `medals` vector now contains the awarded medal.
//      7. Consider creating a shared `MedalStorage` object to manage the available medals.
//--------------------------------------------------------------
#[test]
fun test_medal_award() { 
    let mut test = ts::begin(@USER);
    init(test.ctx());
    test.next_tx(@USER);

    let mut registry = take_shared<HeroRegistry>(&test);
    let mut medalStorage = take_shared<MedalStorage>(&test);

    let mut hero = mint_hero( b"test".to_string(), &mut registry, test.ctx());

    let medal = Medal {
        id: object::new(test.ctx()),
        name: b"medal".to_string(),
    };

    award_medal_of_honor(&mut hero, &mut medalStorage, medal, test.ctx());
    assert!(hero.medals.length()== 1, EMedalOfHonorNotAvailable);
    assert!(hero.medals[0].name == b"medal".to_string(), EMedalOfHonorNotAvailable);

    // Assert medal was stored
    assert!(medalStorage.medals.length() == 1, EMedalOfHonorNotAvailable);

    destroy(hero);

    return_shared(registry);
    return_shared(medalStorage);

    test.end();
}

#[test]
#[expected_failure(abort_code = EMedalOfHonorNotAvailable)]
fun test_medal_award_failure() {
    let mut test = ts::begin(@USER);
    init(test.ctx());
    test.next_tx(@USER);

    let mut registry = take_shared<HeroRegistry>(&test);
    let hero = mint_hero( b"test".to_string(), &mut registry,test.ctx());

    assert!(hero.medals.length() == 1, EMedalOfHonorNotAvailable);
    assert!(hero.medals[0].name == b"medal".to_string(), EMedalOfHonorNotAvailable);

    return_shared(registry);

    destroy(hero);
    
    test.end();
}
