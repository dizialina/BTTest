//
//  ViewController.swift
//  TDDTest
//
//  Created by Alina Egorova on 1/30/18.
//  Copyright © 2018 Alina Egorova. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var game: Game?
    var gameScore: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        game = Game()
    }

    func play(move: String) {
        guard let unwrappedGame = game else {
            print("Game is nil!")
            return
        }
        let response = unwrappedGame.play(move: move)
        gameScore = response.score
    }


}

