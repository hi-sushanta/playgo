import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:playgo/main.dart';
import 'playgame.dart';
import 'about_pages.dart';
import 'fund_page.dart';
import 'tournament_page.dart';
import 'aiPlay.dart';

final userId = FirebaseAuth.instance.currentUser!.uid;

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
      debugShowCheckedModeBanner: false, // Remove the debug banner
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0; // Track the selected index for the navigation bar
  final List<Widget> _pages = [
    GoGameHomePage(),
    GoGameHomePage(),
    GoGameHomePage(),
    const UserProfilePage() 
  ];
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
        body: _pages[_selectedIndex], // Display content based on selected index
        bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
      
        },
        backgroundColor: Colors.white,
        indicatorColor: Colors.amber,
        selectedIndex: _selectedIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.shopping_basket_sharp),
            icon: Icon(Icons.shopping_basket_outlined),
            label: 'Learn',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.history_edu_sharp),
            icon: Icon(Icons.history_edu_outlined),
            label: 'History',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.account_box),
            icon: Icon(Icons.account_box_outlined),
            label: 'About',
          ),
          
        ],
        
      ), 
       
    );
  }
}

class GoGameHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: info!.isLoading,
        builder: (context, bool isLoading, child) {
          // Check if still loading and no data
          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 47, 46, 46),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
          [ Row( 
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("PlayGo",style: TextStyle(color: Colors.white,fontStyle: FontStyle.italic,fontWeight: FontWeight.bold),)
            ],
          ),
          GestureDetector(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(width: 16),
            Icon(Icons.currency_rupee, color: Colors.white),
            Text(
              '${info!.userProfile[info!.uuid]!['fund']}',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(width: 16),
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 14,
              child: Icon(Icons.add, color: Colors.black, size: 18),
            ),
          ],
        ),
        onTap: (){
          Navigator.push(context, MaterialPageRoute(builder: (context) =>  AddCashPage()));
        },
          ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Top Section
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/goBoard.jpg', // Placeholder for the Go board image
                          width: double.maxFinite, 
                        ),
                        Text(
                          "Go Game",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "The Ancient Strategy Game",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) =>  TournamentPage()),);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                            child: Text(
                              "Start Match",
                              style: TextStyle(color: Colors.black, fontSize: 18),
                            ),
                          ),
                          
                        ),
                      ],
                    ),
                  ),
                   // Tournament Banner
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2,horizontal: 16),
                    child: GestureDetector( 
                      child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color.fromARGB(255, 48, 48, 47), const Color.fromARGB(255, 129, 52, 252)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Two Player Game",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  "Entry: Free",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Spacer(),
                                Text(
                                  "Try It Your Family",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const GoBoard(size: 19)));
                    },
                    ),
                  ),
                   // Tournament Banner
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2,horizontal: 16),
                    child: GestureDetector( 
                      child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color.fromARGB(255, 247, 63, 12), const Color.fromARGB(255, 36, 35, 37)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Single Player Game",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  "Entry: Free",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Spacer(),
                                Text(
                                  "Test Your Skill.",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const GoAIBoard(size: 19)));
                    },
                    ),
                  ),

                  // Rules Update Banner
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.rule, color: Colors.white, size: 28),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                "Learn Go Rules\nEverything you need to know about the game",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

         
        ],
      ),
    );
  }
    );
  }
}
