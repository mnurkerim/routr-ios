//
//  ViewController.swift
//  Average Speed
//
//  Created by Muhammed Nurkerim on 30/05/2017.
//  Copyright © 2017 Muhammed Nurkerim. All rights reserved.
//

import UIKit
import CoreLocation
import HealthKit

class ViewController: UIViewController {

    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var averageSpeedLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var paceLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!

    var seconds = 0.0
    var distance = Measurement(value: 0, unit: UnitLength.meters)

    var savedDrive: Drive?

    private let locationManager = LocationManager.shared

    lazy var locations = [CLLocation]()
    lazy var timer = Timer()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        locationManager.requestAlwaysAuthorization()

        stopButton.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    func eachSecond() {
        seconds += 1
        updateDisplay()
    }
    
    private func updateDisplay() {
        let formattedDistance = FormatDisplay.distance(distance)
        let formattedTime = FormatDisplay.time(Int(seconds))
        let formattedPace = FormatDisplay.pace(distance: distance,
                                               seconds: Int(seconds),
                                               outputUnit: UnitSpeed.minutesPerMile)
        
        distanceLabel.text = "Distance:  \(formattedDistance)"
        timeLabel.text = "Time:  \(formattedTime)"
        paceLabel.text = "Pace:  \(formattedPace)"
        averageSpeedLabel.text = String(format: "Average Speed: %.2f mph", ((distance.value / seconds) * 2.23693629))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    private func startLocationUpdates() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 10
        locationManager.startUpdatingLocation()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func startPressed() {
        startButton.isHidden = true
        stopButton.isHidden = false

        locations.removeAll(keepingCapacity: false)
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.eachSecond), userInfo: nil, repeats: true)
        startLocationUpdates()

        seconds = 0.0
        distance = Measurement(value: 0, unit: UnitLength.meters)

        //mapView.hidden = false
    }

    @IBAction func stopPressed() {
        stopButton.isHidden = true
        startButton.isHidden = false

        timer.invalidate()
        locationManager.stopUpdatingLocation()

        let alertController = UIAlertController(title: "Tracking Stopped", message: "Save or discard this session?", preferredStyle: .actionSheet)
        let saveAction = UIAlertAction(title: "Save", style: .default, handler: saveActionHandler)
        let discardAction = UIAlertAction(title: "Discard", style: .default, handler: discardActionHandler)
        alertController.addAction(saveAction)
        alertController.addAction(discardAction)

        self.present(alertController, animated: true, completion: nil)
    }

    func saveDrive() {
        let newDrive = Drive(context: CoreDataStack.context)
        newDrive.distance = self.distance.value
        newDrive.duration = Int16(self.seconds as Double)
        newDrive.timestamp = NSDate()

        for location in locations {
            let savedLocation = Location(context: CoreDataStack.context)
            savedLocation.timestamp = location.timestamp as NSDate
            savedLocation.latitude = location.coordinate.latitude
            savedLocation.longitude = location.coordinate.longitude
            newDrive.addToLocations(savedLocation)
        }
        
        CoreDataStack.saveContext()
        
        savedDrive = newDrive
    }

    func saveActionHandler(action: UIAlertAction) {
        saveDrive()

        let viewController = self.storyboard?.instantiateViewController(withIdentifier: "DetailViewController") as! DetailedViewController
        viewController.drive = savedDrive
        self.navigationController?.pushViewController(viewController, animated: true)
    }

    func discardActionHandler(action: UIAlertAction) {
        self.navigationController?.popToRootViewController(animated: true)
    }
}

// MARK: - CLLocationManagerDelegate
extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for newLocation in locations {
            let howRecent = newLocation.timestamp.timeIntervalSinceNow
            guard newLocation.horizontalAccuracy < 20 && abs(howRecent) < 10 else { continue }
            
            if let lastLocation = self.locations.last {
                let delta = newLocation.distance(from: lastLocation)
                distance = distance + Measurement(value: delta, unit: UnitLength.meters)
                speedLabel.text = String(format:"Speed: %.1f mph", (newLocation.speed * 2.23693629))
            }
            
            self.locations.append(newLocation)
        }
    }
}

