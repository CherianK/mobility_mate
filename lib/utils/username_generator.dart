import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class UsernameGenerator {
  // Adjectives (about 400 words)
  static const List<String> adjectives = [
    // Positive traits
    'Happy', 'Clever', 'Brave', 'Swift', 'Bright', 'Calm', 'Daring', 'Eager',
    'Friendly', 'Gentle', 'Jolly', 'Kind', 'Lively', 'Merry', 'Nimble', 'Proud',
    'Quick', 'Radiant', 'Smart', 'Tender', 'Vibrant', 'Witty', 'Zesty', 'Bold',
    'Cheerful', 'Dashing', 'Elegant', 'Fierce', 'Graceful', 'Honest', 'Joyful',
    'Loyal', 'Mighty', 'Noble', 'Peaceful', 'Quiet', 'Royal', 'Strong', 'True',
    'Valiant', 'Wise', 'Young', 'Zealous', 'Adventurous', 'Ambitious', 'Artistic',
    'Athletic', 'Benevolent', 'Brilliant', 'Charismatic', 'Charming', 'Confident',
    'Creative', 'Curious', 'Dedicated', 'Determined', 'Diligent', 'Diplomatic',
    'Dynamic', 'Energetic', 'Enthusiastic', 'Faithful', 'Fearless', 'Focused',
    'Generous', 'Genuine', 'Grateful', 'Harmonious', 'Helpful', 'Hopeful',
    'Humble', 'Imaginative', 'Independent', 'Innovative', 'Inspiring', 'Intuitive',
    'Jubilant', 'Knowledgeable', 'Loving', 'Magical', 'Magnificent', 'Majestic',
    'Marvelous', 'Mysterious', 'Optimistic', 'Passionate', 'Patient', 'Playful',
    'Powerful', 'Precious', 'Prestigious', 'Proactive', 'Protective', 'Proud',
    'Reliable', 'Resilient', 'Respectful', 'Responsible', 'Romantic', 'Sincere',
    'Spirited', 'Spontaneous', 'Stellar', 'Striking', 'Stunning', 'Superb',
    'Supportive', 'Surprising', 'Tenacious', 'Thoughtful', 'Thrilling', 'Tranquil',
    'Trustworthy', 'Unstoppable', 'Valuable', 'Vibrant', 'Victorious', 'Vigorous',
    'Virtuous', 'Visionary', 'Vivacious', 'Warm', 'Welcoming', 'Wonderful',
    'Wondrous', 'Worthy', 'Youthful', 'Zealous', 'Zestful', 'Zippy',
    
    // Colors
    'Azure', 'Amber', 'Crimson', 'Cobalt', 'Emerald', 'Golden', 'Indigo',
    'Ivory', 'Jade', 'Maroon', 'Navy', 'Olive', 'Pearl', 'Plum', 'Ruby',
    'Sapphire', 'Silver', 'Teal', 'Violet', 'Coral', 'Bronze', 'Copper',
    'Cyan', 'Fuchsia', 'Magenta', 'Mint', 'Ochre', 'Pink', 'Purple', 'Rose',
    
    // Nature-inspired
    'Alpine', 'Arctic', 'Autumn', 'Breezy', 'Coastal', 'Cosmic', 'Crystal',
    'Dawn', 'Dusk', 'Earthy', 'Floral', 'Forest', 'Frosty', 'Glacial',
    'Golden', 'Grassy', 'Hazy', 'Icy', 'Lunar', 'Misty', 'Mountain',
    'Oceanic', 'Pine', 'Rainy', 'Rocky', 'Sandy', 'Solar', 'Starry',
    'Stormy', 'Sunny', 'Thunder', 'Tropical', 'Verdant', 'Wavy', 'Windy',
    
    // Personality traits
    'Adventurous', 'Amusing', 'Artistic', 'Athletic', 'Bold', 'Brave',
    'Calm', 'Careful', 'Caring', 'Charming', 'Cheerful', 'Clever',
    'Compassionate', 'Confident', 'Creative', 'Curious', 'Daring',
    'Dedicated', 'Determined', 'Diligent', 'Diplomatic', 'Dynamic',
    'Eager', 'Energetic', 'Enthusiastic', 'Faithful', 'Fearless',
    'Friendly', 'Funny', 'Generous', 'Gentle', 'Genuine', 'Grateful',
    'Happy', 'Helpful', 'Honest', 'Hopeful', 'Humble', 'Imaginative',
    'Independent', 'Innovative', 'Inspiring', 'Intelligent', 'Intuitive',
    'Jolly', 'Joyful', 'Kind', 'Lively', 'Loving', 'Loyal', 'Merry',
    'Mighty', 'Noble', 'Optimistic', 'Passionate', 'Patient', 'Peaceful',
    'Playful', 'Proud', 'Quick', 'Quiet', 'Radiant', 'Reliable',
    'Resilient', 'Respectful', 'Responsible', 'Romantic', 'Sincere',
    'Smart', 'Spirited', 'Spontaneous', 'Strong', 'Supportive',
    'Thoughtful', 'Trustworthy', 'Understanding', 'Vibrant', 'Warm',
    'Wise', 'Witty', 'Wonderful', 'Youthful', 'Zealous',
    
    // Size and shape
    'Big', 'Bold', 'Broad', 'Compact', 'Curved', 'Deep', 'Dense',
    'Elongated', 'Enormous', 'Expansive', 'Flat', 'Floating', 'Fragile',
    'Giant', 'Grand', 'Great', 'Huge', 'Immense', 'Large', 'Little',
    'Long', 'Massive', 'Mighty', 'Miniature', 'Narrow', 'Petite',
    'Pocket', 'Round', 'Short', 'Small', 'Square', 'Tall', 'Tiny',
    'Vast', 'Wide', 'Winding',
    
    // Time-related
    'Ancient', 'Annual', 'Brief', 'Constant', 'Daily', 'Early', 'Eternal',
    'Fast', 'First', 'Future', 'Historic', 'Immediate', 'Instant', 'Last',
    'Late', 'Lifelong', 'Long', 'Modern', 'Monthly', 'New', 'Old',
    'Ongoing', 'Past', 'Periodic', 'Permanent', 'Present', 'Previous',
    'Quick', 'Rapid', 'Recent', 'Regular', 'Seasonal', 'Short', 'Slow',
    'Sudden', 'Swift', 'Temporary', 'Timeless', 'Timely', 'Urgent',
    'Weekly', 'Yearly', 'Young'
  ];

  // Animals (about 250 words)
  static const List<String> animals = [
    // Land mammals
    'Tiger', 'Lion', 'Wolf', 'Bear', 'Fox', 'Deer', 'Horse', 'Panda',
    'Koala', 'Otter', 'Lynx', 'Puma', 'Jaguar', 'Leopard', 'Panther',
    'Badger', 'Hedgehog', 'Squirrel', 'Rabbit', 'Hare', 'Elk', 'Moose',
    'Gazelle', 'Antelope', 'Zebra', 'Giraffe', 'Elephant', 'Rhino',
    'Hippo', 'Gorilla', 'Chimpanzee', 'Orangutan', 'Lemur', 'Sloth',
    'Armadillo', 'Porcupine', 'Raccoon', 'Skunk', 'Weasel', 'Ferret',
    'Marten', 'Wolverine', 'Coyote', 'Jackal', 'Hyena', 'Cheetah',
    'Caracal', 'Serval', 'Ocelot', 'Bobcat', 'Cougar', 'Mountain Lion',
    
    // Birds
    'Eagle', 'Hawk', 'Falcon', 'Owl', 'Raven', 'Sparrow', 'Robin',
    'Dove', 'Swan', 'Phoenix', 'Dragon', 'Griffin', 'Pegasus', 'Phoenix',
    'Albatross', 'Condor', 'Vulture', 'Kite', 'Harrier', 'Osprey',
    'Kestrel', 'Merlin', 'Peregrine', 'Goshawk', 'Buzzard', 'Kite',
    'Crow', 'Magpie', 'Jay', 'Starling', 'Thrush', 'Nightingale',
    'Lark', 'Finch', 'Canary', 'Cardinal', 'Bluebird', 'Oriole',
    'Tanager', 'Grosbeak', 'Bunting', 'Warbler', 'Vireo', 'Kinglet',
    
    // Sea creatures
    'Dolphin', 'Whale', 'Shark', 'Orca', 'Seal', 'Otter', 'Dolphin',
    'Narwhal', 'Beluga', 'Manatee', 'Dugong', 'Walrus', 'Sea Lion',
    'Octopus', 'Squid', 'Cuttlefish', 'Jellyfish', 'Coral', 'Anemone',
    'Starfish', 'Seahorse', 'Seahorse', 'Manta Ray', 'Stingray',
    'Eel', 'Anglerfish', 'Clownfish', 'Tuna', 'Salmon', 'Trout',
    'Bass', 'Pike', 'Perch', 'Catfish', 'Carp', 'Goldfish',
    
    // Reptiles and amphibians
    'Dragon', 'Lizard', 'Gecko', 'Chameleon', 'Iguana', 'Monitor',
    'Komodo', 'Crocodile', 'Alligator', 'Turtle', 'Tortoise', 'Snake',
    'Python', 'Boa', 'Cobra', 'Viper', 'Rattlesnake', 'Anaconda',
    'Frog', 'Toad', 'Salamander', 'Newt', 'Axolotl', 'Caecilian',
    
    // Insects and arachnids
    'Dragonfly', 'Butterfly', 'Moth', 'Bee', 'Wasp', 'Hornet',
    'Ant', 'Termite', 'Beetle', 'Ladybug', 'Firefly', 'Cricket',
    'Grasshopper', 'Mantis', 'Spider', 'Scorpion', 'Tarantula',
    'Centipede', 'Millipede', 'Cockroach', 'Praying Mantis',
    
    // Mythical creatures
    'Dragon', 'Phoenix', 'Griffin', 'Pegasus', 'Unicorn', 'Mermaid',
    'Centaur', 'Minotaur', 'Sphinx', 'Hydra', 'Chimera', 'Kraken',
    'Yeti', 'Bigfoot', 'Loch Ness', 'Basilisk', 'Cockatrice',
    'Gargoyle', 'Harpy', 'Manticore', 'Roc', 'Thunderbird',
    
    // Small mammals
    'Mouse', 'Rat', 'Hamster', 'Gerbil', 'Guinea Pig', 'Chinchilla',
    'Ferret', 'Weasel', 'Stoat', 'Mink', 'Marten', 'Fisher',
    'Wolverine', 'Badger', 'Otter', 'Raccoon', 'Skunk', 'Coatimundi',
    
    // Primates
    'Monkey', 'Gorilla', 'Chimpanzee', 'Orangutan', 'Gibbon', 'Lemur',
    'Tarsier', 'Loris', 'Marmoset', 'Tamarin', 'Capuchin', 'Macaque',
    
    // Marsupials
    'Kangaroo', 'Wallaby', 'Koala', 'Wombat', 'Tasmanian Devil',
    'Opossum', 'Bandicoot', 'Quokka', 'Numbat', 'Bilby', 'Sugar Glider'
  ];

  static String _generateUsername() {
    final random = Random();
    final adjective = adjectives[random.nextInt(adjectives.length)];
    final animal = animals[random.nextInt(animals.length)];
    return '$adjective $animal';
  }

  static Future<String> getUsername(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    String? savedUsername = prefs.getString('username_$deviceId');

    if (savedUsername == null) {
      // Generate new username
      savedUsername = _generateUsername();

      // Save the username
      await prefs.setString('username_$deviceId', savedUsername);
    }

    return savedUsername;
  }

  static Future<String> resetUsername(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate new username
    final newUsername = _generateUsername();
    
    // Save the new username
    await prefs.setString('username_$deviceId', newUsername);
    
    return newUsername;
  }

  static Future<void> clearAllUsernames() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    
    // Find and remove all username keys
    for (final key in allKeys) {
      if (key.startsWith('username_')) {
        await prefs.remove(key);
      }
    }
  }
} 