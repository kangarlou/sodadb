/*
This file implements a toy, in-memory, JSON-over-HTTP database for demo purposes at KubeCon Europe 2024.
The demo was done as part of the following presentation:
  https://colocatedeventseu2024.sched.com/event/1YFdi/a-case-study-for-improving-network-isolation-in-a-multitenant-kubernetes-cluster-neha-aggarwal-microsoft-ardalan-kangarlou-netapp.

Author: Ardalan Kangarlou
License: BSD
*/

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/mux"
	log "github.com/sirupsen/logrus"
)

type Record struct {
	ID          uint64    `json:"id"`
	Brand       string    `json:"brand"`
	Revenue     int64     `json:"revenue"`
	SodaFormula string    `json:"soda_formula"`
	Timestamp   time.Time `json:"timestamp"`
}

var (
	records                 map[uint64]*Record = make(map[uint64]*Record)
	interfaceName           *string            = flag.String("network_interface", "", "The name of the network interface.")
	listeningIPAddrHostname *string            = flag.String("ipaddr_hostname", "", "The listening IP address or the host name.")
	company                 *string            = flag.String("company", "Kube-Cola", "The name of the company running sodaDB.")
	lock                    *sync.RWMutex      = &sync.RWMutex{}
)

// A function to return the IPv4 address for a given network interface
func getInterfaceIPAddr(interfaceName string) (string, error) {
	var (
		nic      *net.Interface
		err      error
		addrs    []net.Addr
		ipv4Addr net.IP
	)
	if nic, err = net.InterfaceByName(interfaceName); err != nil {
		return "", err
	}
	if addrs, err = nic.Addrs(); err != nil {
		return "", err
	}
	for _, addr := range addrs {
		if ipv4Addr = addr.(*net.IPNet).IP.To4(); ipv4Addr != nil {
			return ipv4Addr.String(), nil
		}
	}
	return "", fmt.Errorf("Couldn't get the IP addrress for %s.\n", interfaceName)
}

func addRecord(w http.ResponseWriter, req *http.Request) {
	var (
		record = &Record{}
		err    error
	)
	if err = json.NewDecoder(req.Body).Decode(record); err != nil {
		log.WithFields(log.Fields{
			"error": err,
			"input": req.Body,
		}).Error("Couldn't decode input.")
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	record.Timestamp = time.Now()
	lock.Lock()
	defer lock.Unlock()
	if _, found := records[record.ID]; found {
		log.WithFields(log.Fields{
			"id": record.ID,
		}).Info("Updated the record.")
	} else {
		log.WithFields(log.Fields{
			"id": record.ID,
		}).Info("Added the record.")
	}
	records[record.ID] = record
}

func listRecords(w http.ResponseWriter, req *http.Request) {
	recordNumbers := make([]uint64, 0)
	lock.RLock()
	defer lock.RUnlock()
	for _, rn := range records {
		recordNumbers = append(recordNumbers, rn.ID)
	}
	json.NewEncoder(w).Encode(recordNumbers)
}

func getRecord(w http.ResponseWriter, req *http.Request) {
	var (
		inputID string
		found   bool
		record  *Record
	)
	vars := mux.Vars(req)
	if inputID, found = vars["id"]; !found {
		log.WithFields(log.Fields{
			"input": req.Body,
		}).Error("Couldn't decode input.")
		http.Error(w, fmt.Sprintf("\"http://server/{id:[0-9]+}\" is the only valid subpath."), http.StatusBadRequest)
		return
	}
	id, err := strconv.ParseUint(inputID, 10, 64)
	if err != nil {
		log.WithFields(log.Fields{
			"error": err,
			"id":    id,
		}).Error("Couldn't decode input.")
		http.Error(w, fmt.Sprintf("\"http://server/{id:[0-9]+}\" is the only valid subpath."), http.StatusBadRequest)
		return
	}
	lock.RLock()
	defer lock.RUnlock()
	if record, found = records[id]; !found {
		log.WithFields(log.Fields{
			"error": err,
			"id":    id,
		}).Debug("Couldn't find the record ID.")
		http.Error(w, fmt.Sprintf("404 page not found; record ID %d doesn't exist.", id), http.StatusNotFound)
		return
	}
	json.NewEncoder(w).Encode(*record)
}

func deleteRecord(w http.ResponseWriter, req *http.Request) {
	var (
		inputID string
		found   bool
	)
	vars := mux.Vars(req)
	if inputID, found = vars["id"]; !found {
		log.WithFields(log.Fields{
			"input": req.Body,
		}).Error("Couldn't decode input.")
		http.Error(w, fmt.Sprintf("\"http://server/{id:[0-9]+}\" is the only valid subpath."), http.StatusBadRequest)
		return
	}
	id, err := strconv.ParseUint(inputID, 10, 64)
	if err != nil {
		log.WithFields(log.Fields{
			"error": err,
			"id":    id,
		}).Error("Couldn't decode input.")
		http.Error(w, fmt.Sprintf("\"http://server/{id:[0-9]+}\" is the only valid subpath."), http.StatusBadRequest)
		return
	}
	lock.Lock()
	defer lock.Unlock()
	if _, found = records[id]; !found {
		log.WithFields(log.Fields{
			"error": err,
			"id":    id,
		}).Debug("Couldn't find the record ID.")
		http.Error(w, fmt.Sprintf("404 page not found; record ID %d doesn't exist.", id), http.StatusNotFound)
		return
	}
	delete(records, id)
	log.WithFields(log.Fields{
		"id": id,
	}).Info("Deleted the record.")
}

func main() {
	var (
		ipAddrHostname string
		err            error
	)

	flag.Parse()
	if *interfaceName == "" && *listeningIPAddrHostname == "" {
		log.Fatal("Either -network_interface or -ipaddr_hostname must be specified!")
	}
	log.SetLevel(log.DebugLevel)

	r := mux.NewRouter()

	if *listeningIPAddrHostname == "" {
		ipAddrHostname, err = getInterfaceIPAddr(*interfaceName)
		if err != nil {
			log.WithFields(log.Fields{
				"error": err,
			}).Fatal("sodaDB failed to get the network interface IP address.")
		}
	} else {
		ipAddrHostname = *listeningIPAddrHostname
	}

	r.HandleFunc("/", addRecord).Host(ipAddrHostname).Methods("POST").Schemes("http").HeadersRegexp("Content-Type", "application/(text|json)")
	r.HandleFunc("/", listRecords).Host(ipAddrHostname).Methods("GET").Schemes("http")
	r.HandleFunc("/{id:[0-9]+}", getRecord).Host(ipAddrHostname).Methods("GET").Schemes("http")
	r.HandleFunc("/{id:[0-9]+}", deleteRecord).Host(ipAddrHostname).Methods("DELETE").Schemes("http")

	log.WithFields(log.Fields{
		"company": *company,
		"ip":      ipAddrHostname,
	}).Infof("sodadb is serving requests.")
	srv := &http.Server{
		Addr:    ":8080",
		Handler: r,
	}
	srv.ListenAndServe()
}
