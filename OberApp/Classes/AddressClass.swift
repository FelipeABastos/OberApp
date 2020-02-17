//
//  AddressClass.swift
//  OberApp
//
//  Created by Felipe Amorim Bastos on 17/02/20.
//  Copyright © 2020 Felipe Amorim Bastos. All rights reserved.
//

import UIKit

class AddressCell: UITableViewCell {
    
    @IBOutlet var lblDate: UILabel?
    @IBOutlet var lblAddress: UILabel?
    
    func loadUI(item: Addresses) {
        lblDate?.text = item.date
        lblAddress?.text = item.address
    }
}

